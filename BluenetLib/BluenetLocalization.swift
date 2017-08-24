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
import BluenetShared


/**
 * Bluenet Localization.
 * This lib is used to handle the iBeacon functionality of the Crownstone. It wraps around the CoreLocation services to handle all iBeacon logic.
 *
 * You can load a classifier into this module using the insertClassifier method.
 *
 * You can use the TrainingHelper class to train a set of TrainingData which you can put into the basic classifier.
 *
 * As long as you can ensure that each beacon's UUID+major+minor combination is unique, you can use this
 * localization lib.
 *
 * You input groups by adding their tracking UUIDS
 *
 * This lib broadcasts the following data:
    topic:                      dataType:               when:
    "iBeaconAdvertisement"      [iBeaconPacket]         Once a second when the iBeacon's are ranged (array of iBeaconPacket objects)
    "enterRegion"               String                  When a region (denoted by referenceId) is entered (data is the referenceId as String)
    "exitRegion"                String                  When a region (denoted by referenceId) is no longer detected (data is the referenceId as String)
    "enterLocation"             Dictionary              ["region": String, "location": String], when a classifier returns a new location, we emit the enter location event. 
                                                        If we were in a location before, there will be an exit location event as well. The region field is the referenceId of the region.
    "exitLocation"              Dictionary              ["region": String, "location": String], when a classifier returns a new location, 
                                                        we emit the exit location event if we were in a different location before.
    "currentLocation"           Dictionary              ["region": String, "location": String], returns the result of the classifier each second as long as it is a valid measurement.
 */
open class BluenetLocalization {
    // Modules
    open var locationManager : LocationManager!
    var eventBus : EventBus!
    var classifier : LocalizationClassifier?
    
    // class vars
    var activeGroupId : String?
    var activeLocationId : String?
    open var indoorLocalizationEnabled : Bool = false
    var initializedLocation : Bool = false
    
    
    // used for debug prints
    var counter : Int64 = 0;
    
    // MARK API
  
    /**
     * On init the handlers and interpreters are bound to the events broadcasted by this lib.
     */
    public init(backgroundEnabled: Bool = true) {
        self.eventBus = EventBus()
        self.locationManager = LocationManager(eventBus: self.eventBus, backgroundRangingEnabled: backgroundEnabled)
        
        // clean the logs every enter region event
        _ = self.eventBus.on("lowLevelEnterRegion",  { _ in LOG.cleanLogs() }) // clean means delete logs that are too old (> 3 days).
        
        // use the ibeacon advertisements for the module logic.
        _ = self.eventBus.on("lowLevelEnterRegion",  self._handleRegionEnter)
        _ = self.eventBus.on("lowLevelExitRegion",   self._handleRegionExit)
        _ = self.eventBus.on("iBeaconAdvertisement", self._updateState)
    }
    
    open func setBackgroundScanning(newBackgroundState: Bool) {
        self.locationManager.setBackgroundScanning(newBackgroundState: newBackgroundState)
    }
    
    /**
     * This method allows you to load a custom classifier into the module. A classifier is optional but required for the enter/exit/current location events.
     */
    open func insertClassifier( classifier : LocalizationClassifier ) {
        self.classifier = classifier
    }
    
    /**
     * The user needs to manually request permission
     */
    open func requestLocationPermission() {
        self.locationManager.requestLocationPermission()
    }
    
    
    /**
     * This provides a very rough estimate of the users location. The location is cached for battery saving. This is accurate up to 3km radius (kCLLocationAccuracyThreeKilometers).
     */
    open func requestLocation() -> CLLocationCoordinate2D {
        return self.locationManager.requestLocation()
    }
    
    /**
     * This method configures an ibeacon with the ibeaconUUID you provide. The dataId is used to notify
     * you when this region is entered as well as to keep track of which classifiers belong to which datapoint in your reference.
     */
    open func trackIBeacon(uuid: String, referenceId: String) {
        if (uuid.characters.count < 30) {
            LOG.warn("BLUENET LOCALIZATION ---- Cannot track \(referenceId) with UUID \(uuid)")
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
        self.locationManager.refreshRegionState()
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
        self.locationManager.pauseTrackingRegions()
    }
    
    /**
     *  Continue tracking iBeacons. Will trigger enterRegion and enterLocation again.
     *  Can be called multiple times without duplicate events.
     */
    open func resumeTracking() {
        if (self.locationManager.isMonitoringRegions() == false) {
            activeGroupId = nil
            activeLocationId = nil
            
            self.locationManager.startMonitoringRegions()
        }
    }
    
    
    /**
     * This will enable the classifier. It requires the TrainingData to be setup and will trigger the current/enter/exitRoom events
     * This should be used if the user is sure the TrainingData process has been finished.
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
     * Make sure you hook this up to your AppDelegate method for applicationWillEnterForeground. Required for disabling background ranging.
     */
    open func applicationWillEnterForeground() {
        self.locationManager.applicationWillEnterForeground()
    }
    
    /**
     * Make sure you hook this up to your AppDelegate method for applicationWillEnterForeground. Required for disabling background ranging.
     */
    open func applicationDidEnterBackground() {
        self.locationManager.applicationDidEnterBackground()
    }
    
    // MARK: Util
    
    func _updateState(_ ibeaconData: Any) {
        if let data = ibeaconData as? [iBeaconPacket] {
            // log ibeacon receiving for debugging purposes {
            self.counter += 1
            LOG.verbose("received iBeacon nr: \(self.counter) classifierState: \(indoorLocalizationEnabled) amountOfBeacons: \(data.count) activeRegionId: \(String(describing: self.activeGroupId))")
            for packet in data {
                LOG.verbose("received iBeacon DETAIL \(packet.idString) \(packet.rssi) \(packet.referenceId)")
            }
            
            if (self.activeGroupId != nil) {
                // if we have data in this payload.
                if (data.count > 0 && self.classifier != nil && self.indoorLocalizationEnabled) {
                    let currentLocation = self.classifier!.classify(data, referenceId: self.activeGroupId!)
                    if (currentLocation != nil) {
                        if (self.activeLocationId != currentLocation) {
                            self._moveToNewLocation(currentLocation!)
                        }
                    }
                    var locationDict = [String: String?]()
                    locationDict["region"] = self.activeGroupId
                    locationDict["location"] = self.activeLocationId
                    self.eventBus.emit("currentLocation", locationDict)
                }
            }
        }
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
            LOG.info("REGION EXIT \(regionId)")
            
            if (self.activeGroupId != nil || self.initializedLocation == false) {
                self.eventBus.emit("exitRegion", regionId)
            }
            self.initializedLocation = true
        }
        else {
            LOG.info("REGION EXIT (id not string)")
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
            self.initializedLocation = true
            self.activeGroupId = regionString
            
            LOG.info("REGION ENTER \(regionString)")
        }
        else {
            LOG.info("REGION ENTER region not string")
        }
    }

   
}

