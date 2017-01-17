//
//  BluenetNavigation.swift
//  BluenetLibIOS
//
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import SwiftyJSON


/**
 * Bluenet Localization.
 * This lib is used to interact with the indoor localization algorithms of the Crownstone.
 *
 *
 * With this lib you train fingerprints, get and load them and determine in which location you are.
 * It wraps around the CoreLocation services to handle all iBeacon logic.
 * As long as you can ensure that each beacon's UUID+major+minor combination is unique, you can use this
 * localization lib.
 *
 * You input groups by adding their tracking UUIDS
 * You input locations by providing their fingerprints or training them.
 *
 * This lib broadcasts the following data:
    topic:                      dataType:               when:
    "iBeaconAdvertisement"      [iBeaconPacket]         Once a second when the iBeacon's are ranged   (array of iBeaconPacket objects)
    "enterRegion"               String                  When a region (denoted by referenceId) is entered (data is the referenceId as String)
    "exitRegion"                String                  When a region (denoted by referenceId) is no longer detected (data is the referenceId as String)
    "enterLocation"             String                  When the classifier determines the user has entered a new location (data is the locationId as String)
    "exitLocation"              String                  When the classifier determines the user has left his location in favor 
                                                            of a new one. Not triggered when region is left (data is the locationId as String)
    "currentLocation"           String                  Once a second when the iBeacon's are ranged and the classifier makes a prediction (data is the locationId as String)
 */
open class BluenetLocalization {
    open var locationManager : LocationManager!
    var eventBus : EventBus!
    
    var counter : Int64 = 0;
    
    var classifier = [String: ClassifierWrapper]()
    var collectingFingerprint : Fingerprint?
    var collectingCallback : voidCallback?
    var activeGroupId : String?
    var activeLocationId : String?
    var indoorLocalizationConsecutiveMatchesThreshold = 2
    open var indoorLocalizationEnabled : Bool = false
    var indoorLocalizationConsecutiveMatches = 0
    var lastMeasurement = ""
    var fingerprintData = [String : [String : Fingerprint]]() // referenceId: locationId: Fingerprint
    
    // MARK API
  
    /**
     * On init the handlers and interpreters are bound to the events broadcasted by this lib.
     */
    public init() {
        self.eventBus = EventBus()
        self.locationManager = LocationManager(eventBus: self.eventBus)
        _ = self.eventBus.on("iBeaconAdvertisement", self._updateState);
        _ = self.eventBus.on("lowLevelEnterRegion",  self._handleRegionEnter);
        _ = self.eventBus.on("lowLevelExitRegion",   self._handleRegionExit);
    }
    
    
    /**
     * The user needs to manually request permission
     */
    open func requestLocationPermission() {
        self.locationManager.requestLocationPermission()
    }
    
    /**
     * This method configures an ibeacon with the ibeaconUUID you provide. The dataId is used to notify
     * you when this region is entered as well as to keep track of which classifiers belong to which datapoint in your reference.
     */
    open func trackIBeacon(uuid: String, referenceId: String) {
        // verify permission
        self.locationManager.requestLocationPermission()
        
        
        if (uuid.characters.count < 30) {
            Log("BLUENET LOCALIZATION ---- Cannot track \(referenceId) with UUID \(uuid)")
        }
        else {
            let trackStone = iBeaconContainer(referenceId: referenceId, uuid: uuid)
            self.locationManager.trackBeacon(trackStone)
        }
    }
    
    /**
     * This method will call requestState on every registered region.
     */
    open func refreshLocation() {
        self.locationManager.refreshLocation()
    }
    
    /**
     * This can be used to have another way of resetting the enter/exit events. In certain cases (ios 10) the exitRegion event might not be fired correctly.
     * The app can correct for this and implement it's own exitRegion logic. By calling this afterwards the lib will fire a new enter region event when it sees
     * new beacons.
     */	
    open func forceClearActiveRegion() {
        activeGroupId = nil
        activeLocationId = nil
    }
   
    /**
     *  This will stop listening to any and all updates from the iBeacon tracking. Your app may fall asleep.
     *  It will also remove the list of all tracked iBeacons.
     */
    open func clearTrackedBeacons() {
        activeGroupId = nil
        activeLocationId = nil
        self.locationManager.clearTrackedBeacons()
    }
    
    
    /**
     * This will stop listening to a single iBeacon uuid and remove it from the list. This is called when you remove the region from
     * the list of stuff you want to listen to. It will not be resumed by resumeTracking.
     */
    open func stopTrackingIBeacon(_ uuid: String) {
        self.locationManager.stopTrackingIBeacon(uuid);
    }
    
    /**
     *  This will pause listening to any and all updates from the iBeacon tracking. Your app may fall asleep. It can be resumed by 
     *  the resumeTracking method.
     */
    open func pauseTracking() {
        self.locationManager.pauseTrackingIBeacons()
    }
    
    /**
     *  Continue tracking iBeacons. Will trigger enterRegion and enterLocation again.
     *  Can be called multiple times without duplicate events.
     */
    open func resumeTracking() {
        if (self.locationManager.isTracking() == false) {
            activeGroupId = nil
            activeLocationId = nil
            
            self.locationManager.startTrackingIBeacons()
        }
    }
    
    
    /**
     * This will enable the classifier. It requires the fingerprints to be setup and will trigger the current/enter/exitRoom events
     * This should be used if the user is sure the fingerprinting process has been finished.
     */
    open func startIndoorLocalization() {
        activeLocationId = nil
        self.indoorLocalizationEnabled = true;
    }
    /**
     * This will disable the classifier. The current/enter/exitRoom events will no longer be fired.
     */
    open func stopIndoorLocalization() {
        self.indoorLocalizationEnabled = false;
    }
    
    /**
     * Subscribe to a topic with a callback. This method returns an Int which is used as identifier of the subscription.
     * This identifier is supplied to the off method to unsubscribe.
     */
    open func on(_ topic: String, _ callback: @escaping eventCallback) -> voidCallback {
        return self.eventBus.on(topic, callback)
    }
    
    /**
     * Load a fingerprint into the classifier(s) for the specified groupId and locationId.
     * The fingerprint can be constructed from a string by using the initializer when creating the Fingerprint object
     */
    open func loadFingerprint(referenceId: String, locationId: String, fingerprint: Fingerprint) {
        self._loadFingerprint(referenceId, locationId: locationId, fingerprint: fingerprint)
    }
   
    
    /**
     * Obtain the fingerprint for this groupId and locationId. usually done after collecting it.
     * The user is responsible for persistently storing and loading the fingerprints.
     */
    open func getFingerprint(_ referenceId: String, locationId: String) -> Fingerprint? {
        if let groupFingerprints = self.fingerprintData[referenceId] {
            if let returnPrint = groupFingerprints[locationId] {
                return returnPrint
            }
        }
        return nil
    }
    
    
    /**
     * Start collecting a fingerprint.
     */
    open func startCollectingFingerprint() {
        self.collectingFingerprint = Fingerprint()
        self._registerFingerprintCollectionCallback();
    }
    
    /**
     * Pause collecting a fingerprint. Usually when something in the app would interrupt the user.
     */
    open func pauseCollectingFingerprint() {
        self._removeFingerprintListener()
    }
    
    /**
     * Resume collecting a fingerprint.
     */
    open func resumeCollectingFingerprint() {
        self._registerFingerprintCollectionCallback()
    }
    
    /**
     * Stop collecting a fingerprint without loading it into the classifier.
     */
    open func abortCollectingFingerprint() {
        self._cleanupCollectingFingerprint()
    }
   
    
    /**
     * Finalize collecting a fingerprint and store it in the appropriate classifier based on the referenceId and the locationId.
     */
    open func finalizeFingerprint(_ referenceId: String, locationId: String) {
        if (self.collectingFingerprint != nil) {
            if (self.fingerprintData[referenceId] == nil) {
                self.fingerprintData[referenceId] = [String: Fingerprint]()
            }
            self.fingerprintData[referenceId]![locationId] = self.collectingFingerprint!
            self._loadFingerprint(referenceId, locationId: locationId, fingerprint: self.collectingFingerprint!)
        }
        self._cleanupCollectingFingerprint()
    }
    
    // MARK: UTIL
    
    func _registerFingerprintCollectionCallback() {
        // in case this method is called wrongly, clean up the last listener
        self._removeFingerprintListener()
        
        // start listening to the event stream
        self.collectingCallback = self.eventBus.on("iBeaconAdvertisement", {ibeaconData in
            if let data = ibeaconData as? [iBeaconPacket] {
                if let Fingerprint = self.collectingFingerprint {
                    Fingerprint.collect(data)
                }
                else {
                    self._cleanupCollectingFingerprint()
                }
            }
        });
    }
    
    func _removeFingerprintListener() {
        if let unsubscribe = self.collectingCallback {
            unsubscribe()
        }
    }
    
    
    func _cleanupCollectingFingerprint() {
        self._removeFingerprintListener()
        self.collectingCallback = nil
        self.collectingFingerprint = nil
    }
    
    func _updateState(_ ibeaconData: Any) {
        if let data = ibeaconData as? [iBeaconPacket] {
            // log ibeacon receiving for debugging purposes
            if (DEBUG_LOG_ENABLED) {
                self.counter += 1
                LogFile("received iBeacon nr: \(self.counter) classifierState: \(indoorLocalizationEnabled) amountOfBeacons: \(data.count) activeRegionId: \(self.activeGroupId)")
                for packet in data {
                    LogFile("received iBeacon DETAIL \(packet.idString) \(packet.rssi) \(packet.referenceId)")
                }
            }
            if (data.count > 0 && self.activeGroupId != nil) {
                // create classifiers for this group if required.
                if (self.classifier[self.activeGroupId!] == nil) {
                    self.classifier[self.activeGroupId!] = ClassifierWrapper()
                }
                
                // check if we are using the indoor localization.
                if (self.indoorLocalizationEnabled) {
                    let classificationResult = self._evaluateData(data)
                    
                    // the result is valid if there are at least 3 samples and if there is atleast fingerprints loaded.
                    if (classificationResult.valid == true) {
                        let currentLocation = classificationResult.location
                        // check if we are moving to a new location.
                        if (self.activeLocationId != currentLocation) {
                            
                            // we require that we measure the same location at least indoorLocalizationConsecutiveMatchesThreshold times.
                            if (self.lastMeasurement == currentLocation) {
                                self.indoorLocalizationConsecutiveMatches += 1
                                if (self.indoorLocalizationConsecutiveMatches == self.indoorLocalizationConsecutiveMatchesThreshold) {
                                    self._moveToNewLocation(currentLocation)
                                    self.indoorLocalizationConsecutiveMatches = 0
                                }
                            }
                            else {
                                self.indoorLocalizationConsecutiveMatches = 0
                            }
                        }
                        self.lastMeasurement = currentLocation
                    }
                }
            }
        }
    }
    
    func _loadFingerprint(_ referenceId: String, locationId: String, fingerprint: Fingerprint) {
        if (self.classifier[referenceId] == nil) {
            self.classifier[referenceId] = ClassifierWrapper()
        }
        self.classifier[referenceId]!.loadFingerprint(locationId, fingerprint: fingerprint)
    }
    
    func _moveToNewLocation(_ newLocation: String ) {
        var locationDict = [String: String?]()
        locationDict["region"] = self.activeGroupId
        
        if (self.activeLocationId != nil) {
            // put the precious location in the dictionary
            locationDict["location"] = self.activeLocationId
            self.eventBus.emit("exitLocation", locationDict)
        }
        
        self.activeLocationId = newLocation
        // put the new location in the dictionary
        locationDict["location"] = self.activeLocationId
        
        self.eventBus.emit("enterLocation", locationDict)
    }
    
    func _handleRegionExit(_ regionId: Any) {
        if regionId is String {
            if (DEBUG_LOG_ENABLED) {
                Log("REGION EXIT \(regionId)")
            }
            if (self.activeGroupId != nil) {
                self.eventBus.emit("exitRegion", regionId)
            }
        }
        else {
            if (DEBUG_LOG_ENABLED) {
                Log("REGION EXIT (id not string)")
            }
            if (self.activeGroupId != nil) {
                self.eventBus.emit("exitRegion", self.activeGroupId!)
            }
        }
        self.activeGroupId = nil
        
    }
    
    func _handleRegionEnter(_ regionId: Any) {
        if let regionString = regionId as? String {
            if (self.activeGroupId != nil) {
                if (self.activeGroupId! != regionString) {
                    self.eventBus.emit("exitRegion", self.activeGroupId!)
                    self.eventBus.emit("enterRegion", regionString)
                }
            }
            else {
                self.eventBus.emit("enterRegion", regionString)
            }
            self.activeGroupId = regionString
            
            if (DEBUG_LOG_ENABLED) {
                Log("REGION ENTER \(regionString)")
            }
        }
        else {
            if (DEBUG_LOG_ENABLED) {
                Log("REGION ENTER region not string")
            }
        }
        
        
    }    
    
    func _evaluateData(_ data : [iBeaconPacket]) -> ClassifierResult {
        let result = self.classifier[self.activeGroupId!]!.predict(data)
        if (result.valid == true) {
            var locationDict = [String: String]()
            locationDict["region"] = self.activeGroupId
            locationDict["location"] = result.location
            
            self.eventBus.emit("currentLocation", locationDict)
        }
        return result
    }

   
}

