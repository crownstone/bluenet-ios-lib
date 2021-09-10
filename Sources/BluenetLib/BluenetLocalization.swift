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
import PromiseKit

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
#if os(iOS)
public class BluenetLocalization {
    // Modules
    public var locationManager : LocationManager!
    var eventBus : EventBus!
    
    var beaconUuidMap  = [String: String]()
    var referenceIdMap = [String: String]()
    var regionPresenceState = [String: Bool]()

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

    }
    
    func _clearPresentState() {
        for (refId, _) in self.regionPresenceState {
            self.regionPresenceState[refId] = false
        }
    }
    
    public func setBackgroundScanning(newBackgroundState: Bool) {
        self.locationManager.setBackgroundScanning(newBackgroundState: newBackgroundState)
    }
    
    /**
     * The user needs to manually request permission
     */
    public func requestLocationPermission() {
        self.locationManager.requestLocationPermission()
    }
    
    
    /**
     * This provides a very rough estimate of the users location. The location is cached for battery saving. This is accurate up to 3km radius (kCLLocationAccuracyThreeKilometers).
     */
    public func requestLocation() -> Promise<CLLocationCoordinate2D> {
        return self.locationManager.requestLocation()
    }
    
    /**
     * This method configures an ibeacon with the ibeaconUUID you provide. The dataId is used to notify
     * you when this region is entered as well as to keep track of which classifiers belong to which datapoint in your reference.
     */
    public func trackIBeacon(uuid: String, referenceId: String) {
        if (uuid.count < 30) {
            LOG.warn("BLUENET LOCALIZATION ---- Cannot track \(referenceId) with UUID \(uuid)")
        }
        else {
            self.referenceIdMap[referenceId] = uuid
            self.beaconUuidMap[uuid] = referenceId
            
            let trackStone = iBeaconContainer(referenceId: referenceId, uuid: uuid)
            self.locationManager.trackBeacon(trackStone)
        }
    }
    
    /**
     * This method will call requestState on every registered region.
     */
    public func refreshLocation() {
        self.locationManager.refreshRegionState()
    }
    
   
    /**
     *  This will stop listening to any and all updates from the iBeacon tracking. Your app may fall asleep.
     *  It will also remove the list of all tracked iBeacons.
     */
    public func clearTrackedBeacons() {
        self._clearPresentState()
        self.locationManager.clearTrackedBeacons()
    }
    
    /**
     * Is currently scanning for iBeacons
     */
    public func getTrackingState() -> [String: Bool] {
        return self.locationManager.getTrackingState();
    }
    
    
    /**
     * This will stop listening to a single iBeacon uuid and remove it from the list. This is called when you remove the region from
     * the list of stuff you want to listen to. It will not be resumed by resumeTracking.
     */
    public func stopTrackingIBeacon(_ uuid: String) {
        if let referenceId = self.beaconUuidMap[uuid] {
            self.regionPresenceState[referenceId] = false
        }
        self.locationManager.stopTrackingIBeacon(uuid);
    }
    
    /**
     *  This will pause listening to any and all updates from the iBeacon tracking. Your app may fall asleep. It can be resumed by 
     *  the resumeTracking method.
     */
    public func pauseTracking() {
        self.locationManager.pauseMonitoringRegions()
    }
    
    /**
     *  Continue tracking iBeacons. Will trigger enterRegion and enterLocation again.
     *  Can be called multiple times without duplicate events.
     */
    public func resumeTracking() {
        if (self.locationManager.isMonitoringRegions() == false) {
            self._clearPresentState()
            
            self.locationManager.startMonitoringRegions()
        }
    }
    
    
    /**
     * Subscribe to a topic with a callback. This method returns an Int which is used as identifier of the subscription.
     * This identifier is supplied to the off method to unsubscribe.
     */
    public func on(_ topic: String, _ callback: @escaping eventCallback) -> voidCallback {
        return self.eventBus.on(topic, callback)
    }
    
    /**
     * Make sure you hook this up to your AppDelegate method for applicationWillEnterForeground. Required for disabling background ranging.
     */
    public func applicationWillEnterForeground() {
        self.locationManager.applicationWillEnterForeground()
    }
    
    /**
     * Make sure you hook this up to your AppDelegate method for applicationWillEnterForeground. Required for disabling background ranging.
     */
    public func applicationDidEnterBackground() {
        self.locationManager.applicationDidEnterBackground()
    }
    
    // MARK: Util
    
    
    func _handleRegionExit(_ regionId: Any) {
        if let regionIdString = regionId as? String {
            LOG.info("BluenetLocalization: REGION EXIT \(regionIdString)")
            if (self.regionPresenceState[regionIdString] != nil) {
                if (self.regionPresenceState[regionIdString] == true) {
                    self.regionPresenceState[regionIdString] = false
                    self.eventBus.emit("exitRegion", regionIdString)
                }
            }
        }
        else {
            LOG.info("BluenetLocalization: REGION EXIT (id not string)")
        }
    }
    
    func _handleRegionEnter(_ regionId: Any) {
        if let regionIdString = regionId as? String {
            LOG.info("BluenetLocalization: REGION ENTER \(regionIdString)")
            if (self.regionPresenceState[regionIdString] == false || self.regionPresenceState[regionIdString] == nil) {
                self.regionPresenceState[regionIdString] = true
                self.eventBus.emit("enterRegion", regionIdString)
            }
        }
        else {
            LOG.info("BluenetLocalization: REGION ENTER region not string")
        }
    }
}

#endif
