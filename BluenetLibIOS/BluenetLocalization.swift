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
    "enterRegion"               String                  When a region (denoted by groupId) is entered (data is the groupId as String)
    "exitRegion"                String                  When a region (denoted by groupId) is no longer detected (data is the groupId as String)
    "enterLocation"             String                  When the classifier determines the user has entered a new location (data is the locationId as String)
    "exitLocation"              String                  When the classifier determines the user has left his location in favor 
                                                            of a new one. Not triggered when region is left (data is the locationId as String)
    "currentLocation"           String                  Once a second when the iBeacon's are ranged and the classifier makes a prediction (data is the locationId as String)
 */
public class BluenetLocalization {
    public var locationManager : LocationManager!
    var eventBus : EventBus!
    
    var classifier = [String: ClassifierWrapper]()
    var collectingFingerprint : Fingerprint?
    var collectingCallbackId : Int?
    var activeGroupId : String?
    var activeLocationId : String?
    var certainty = 2
    var sameCounter = 0
    var lastMeasurement = ""
    var fingerprintData = [String : [String : Fingerprint]]() // groupId: locationId: Fingerprint
    
    // MARK API
    
    /**
     * On init the handlers and interpreters are bound to the events broadcasted by this lib.
     */
    public init() {
        self.eventBus = EventBus()
        self.locationManager = LocationManager(eventBus: self.eventBus)
        self.eventBus.on("iBeaconAdvertisement", self._updateState);
        self.eventBus.on("lowLevelEnterRegion",  self._handleRegionEnter);
        self.eventBus.on("lowLevelExitRegion",   self._handleRegionExit);
    }
    
    
    /**
     * This method configures an ibeacon with the ibeaconUUID you provide. The groupId is used to notify
     * you when this region is entered as well as to keep track of which classifiers belong to which group.
     */
    public func trackIBeacon(uuid: String, groupId: String) {
        let trackStone = iBeaconContainer(groupId: groupId, uuid: uuid)
        self.locationManager.trackBeacon(trackStone)
    }
   
    /**
     *  This will stop listening to any and all updates from the iBeacon tracking. Your app may fall asleep.
     *  It will also remove the list of all tracked iBeacons.
     */
    public func clearTrackedBeacons() {
        self.locationManager.clearTrackedBeacons()
    }
    
    /**
     *  This will stop listening to any and all updates from the iBeacon tracking. Your app may fall asleep.
     */
    public func stopTracking() {
        self.locationManager.stopTrackingIBeacons()
    }
    
    /**
     *  Continue tracking iBeacons. Will trigger enterRegion and enterLocation again.
     *  Can be called multiple times without duplicate events.
     */
    public func resumeTracking() {
        if (self.locationManager.isTracking() == false) {
            activeGroupId = nil
            activeLocationId = nil
            
            self.locationManager.startTrackingIBeacons()
        }
    }
    
    /**
     * Subscribe to a topic with a callback. This method returns an Int which is used as identifier of the subscription.
     * This identifier is supplied to the off method to unsubscribe.
     */
    public func on(topic: String, _ callback: (AnyObject) -> Void) -> Int {
        return self.eventBus.on(topic, callback)
    }
    
    
    /**
     * Unsubscribe from a subscription.
     * This identifier is obtained as a return of the on() method.
     */
    public func off(id: Int) {
        self.eventBus.off(id);
    }
    
    
    /**
     * Load a fingerprint into the classifier(s) for the specified groupId and locationId.
     * The fingerprint can be constructed from a string by using the initializer when creating the Fingerprint object
     */
    public func loadFingerprint(groupId: String, locationId: String, fingerprint: Fingerprint) {
        self._loadFingerprint(groupId, locationId: locationId, fingerprint: fingerprint)
    }
   
    
    /**
     * Obtain the fingerprint for this groupId and locationId. usually done after collecting it.
     * The user is responsible for persistently storing and loading the fingerprints.
     */
    public func getFingerprint(groupId: String, locationId: String) -> Fingerprint? {
        if let groupFingerprints = self.fingerprintData[groupId] {
            if let returnPrint = groupFingerprints[locationId] {
                return returnPrint
            }
        }
        return nil
    }
    
    
    /**
     * Start collecting a fingerprint.
     */
    public func startCollectingFingerprint() {
        self.collectingFingerprint = Fingerprint()
        self._registerFingerprintCollectionCallback();
    }
    
    /**
     * Pause collecting a fingerprint. Usually when something in the app would interrupt the user.
     */
    public func pauseCollectingFingerprint() {
        self._removeFingerprintListener()
    }
    
    /**
     * Resume collecting a fingerprint.
     */
    public func resumeCollectingFingerprint() {
        self._registerFingerprintCollectionCallback()
    }
    
    /**
     * Stop collecting a fingerprint without loading it into the classifier.
     */
    public func abortCollectingFingerprint() {
        self._cleanupCollectingFingerprint()
    }
   
    
    /**
     * Finalize collecting a fingerprint and store it in the appropriate classifier based on the groupId and the locationId.
     */
    public func finalizeFingerprint(groupId: String, locationId: String) {
        if (self.collectingFingerprint != nil) {
            if (self.fingerprintData[groupId] == nil) {
                self.fingerprintData[groupId] = [String: Fingerprint]()
            }
            self.fingerprintData[groupId]![locationId] = self.collectingFingerprint!
            self._loadFingerprint(groupId, locationId: locationId, fingerprint: self.collectingFingerprint!)
        }
        self._cleanupCollectingFingerprint()
    }
    
    // MARK: UTIL
    
    func _registerFingerprintCollectionCallback() {
        // in case this method is called wrongly, clean up the last listener
        self._removeFingerprintListener()
        
        // start listening to the event stream
        self.collectingCallbackId = self.eventBus.on("iBeaconAdvertisement", {ibeaconData in
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
        if let callbackId = self.collectingCallbackId {
            self.off(callbackId)
        }
    }
    
    
    func _cleanupCollectingFingerprint() {
        self._removeFingerprintListener()
        self.collectingCallbackId = nil
        self.collectingFingerprint = nil
    }
    
    func _updateState(ibeaconData: AnyObject) {
        if let data = ibeaconData as? [iBeaconPacket] {
            if (data.count > 0 && self.activeGroupId != nil) {
                // create classifiers for this group if required.
                if (self.classifier[self.activeGroupId!] == nil) {
                    self.classifier[self.activeGroupId!] = ClassifierWrapper()
                }
                
                let classificationResult = self._evaluateData(data)
                if (classificationResult.valid == true) {
                    let currentLocation = classificationResult.location
                    if (self.activeLocationId != currentLocation) {
                        if (self.lastMeasurement == currentLocation) {
                            self.sameCounter += 1
                            if (self.sameCounter == self.certainty) {
                                self._moveToNewLocation(currentLocation)
                                self.sameCounter = 0
                            }
                        }
                        else {
                            self.sameCounter = 0
                        }
                    }
                    self.lastMeasurement = currentLocation
                }
            }
        }
    }
    
    func _loadFingerprint(groupId: String, locationId: String, fingerprint: Fingerprint) {
        if (self.classifier[groupId] == nil) {
            self.classifier[groupId] = ClassifierWrapper()
        }
        self.classifier[groupId]!.loadFingerprint(locationId, fingerprint: fingerprint)
    }
    
    func _moveToNewLocation(newLocation: String ) {
        if (self.activeLocationId != nil) {
            self.eventBus.emit("exitLocation", self.activeLocationId!)
        }
        self.activeLocationId = newLocation
        self.eventBus.emit("enterLocation", self.activeLocationId!)
    }
    
    func _handleRegionExit(regionId: AnyObject) {
        if regionId is String {
            if (self.activeGroupId != nil) {
                self.eventBus.emit("exitRegion", regionId)
            }
        }
        else {
            if (self.activeGroupId != nil) {
                self.eventBus.emit("exitRegion", self.activeGroupId!)
            }
        }
        self.activeGroupId = nil
    }
    
    func _handleRegionEnter(regionId: AnyObject) {
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
        }
    }    
    
    func _evaluateData(data : [iBeaconPacket]) -> ClassifierResult {
        let result = self.classifier[self.activeGroupId!]!.predict(data)
        if (result.valid == true) {
            self.eventBus.emit("currentLocation", result.location)
        }
        return result
    }

   
}

