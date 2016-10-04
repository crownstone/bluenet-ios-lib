//
//  guideStoneManager.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 11/04/16./Users/alex/Library/Developer/Xcode/DerivedData/BluenetLibIOS-dcbozafhnxsptqgpaxsncklrmaoz/Build/Products/Debug-iphoneos/BluenetLibIOS.framework
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreLocation
import SwiftyJSON
import UIKit

public class LocationManager : NSObject, CLLocationManagerDelegate {
    var manager : CLLocationManager!
    
    var eventBus : EventBus!
    var trackingBeacons = [iBeaconContainer]()
    var appName = "Crownstone"
    var started = false
    var trackingState = false

    
    public init(eventBus: EventBus) {
        super.init();
        
        self.eventBus = eventBus;
        
        //print("Starting location manager")
        self.manager = CLLocationManager()
        self.manager.delegate = self;
        
        CLLocationManager.locationServicesEnabled()
        
        print("------ BLUENET_LIB_NAV: location services enabled: \(CLLocationManager.locationServicesEnabled())");
        print("------ BLUENET_LIB_NAV: ranging services enabled: \(CLLocationManager.isRangingAvailable())");
        
        self.stopTrackingAllRegions()

        self.check()
    }
    
    public func trackBeacon(beacon: iBeaconContainer) {
        if (!self._beaconInList(beacon, list: self.trackingBeacons)) {
            trackingBeacons.append(beacon);
            if (self.started == true) {
                self.manager.startMonitoringForRegion(beacon.region)
                self.manager.requestStateForRegion(beacon.region)
            }
        }
        
        self.start();
    }
    
    public func check() {
        self.locationManager(self.manager, didChangeAuthorizationStatus: CLLocationManager.authorizationStatus())
    }
    
    public func stopTrackingAllRegions() {
        // stop monitoring all previous regions
        for region in self.manager.monitoredRegions {
            print ("------ BLUENET_LIB_NAV: INITIALIZATION: stop monitoring old region: \(region)")
            self.manager.stopMonitoringForRegion(region)
        }
    }
    
    public func clearTrackedBeacons() {
        self.stopTrackingIBeacons()
        self.trackingBeacons.removeAll()
    }
    
    
    public func stopTrackingIBeacon(uuid: String) {
        // stop monitoring all becons
        var targetIndex : Int? = nil;
        var uuidObject = NSUUID(UUIDString : uuid)
        if (uuidObject == nil) {
            return
        }
        
        var uuidString = uuidObject!.UUIDString
        for (index, beacon) in self.trackingBeacons.enumerate() {
            if (beacon.UUID.UUIDString == uuidString) {
                self.manager.stopRangingBeaconsInRegion(beacon.region)
                self.manager.stopMonitoringForRegion(beacon.region)
                targetIndex = index;
                break
            }
        }

        if (targetIndex != nil) {
            self.trackingBeacons.removeAtIndex(targetIndex!)
            if (self.trackingBeacons.count == 0) {
                self.trackingState = false
            }
        }
        
    }
    
    public func stopTrackingIBeacons() {
        // stop monitoring all becons
        for beacon in self.trackingBeacons {
            self.manager.stopRangingBeaconsInRegion(beacon.region)
            self.manager.stopMonitoringForRegion(beacon.region)
        }
        self.trackingState = false
    }
    
    public func isTracking() -> Bool {
        return self.trackingState
    }
    
    public func startTrackingIBeacons() {
        // reinitialize
        for beacon in self.trackingBeacons {
            self.manager.startMonitoringForRegion(beacon.region)
            self.manager.requestStateForRegion(beacon.region)
        }
    }
    
    func resetBeaconRanging() {
        print ("------ BLUENET_LIB_NAV: Resetting ibeacon tracking")
        self.stopTrackingIBeacons()
        self.startTrackingIBeacons()
        self.trackingState = true
    }
    
    func start() {
        self.manager.startUpdatingLocation()
        if (self.manager.respondsToSelector(Selector("allowsBackgroundLocationUpdates"))) {
            self.manager.allowsBackgroundLocationUpdates = true
        }
        
        self.resetBeaconRanging();
        self.started = true
    }
    
    func startWithoutBackground() {
        self.manager.startUpdatingLocation()
        self.resetBeaconRanging();
        self.started = true
    }
    
    public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch (CLLocationManager.authorizationStatus()) {
        case .NotDetermined:
            print("------ BLUENET_LIB_NAV: location NotDetermined")
            /*
             First you need to add NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription(if you want to use in background) in your info.plist file OF THE PROGRAM THAT IMPLEMENTS THIS!
             */
            manager.requestAlwaysAuthorization()
        case .Restricted:
            print("------ BLUENET_LIB_NAV: location Restricted")
        case .Denied:
            showLocationAlert()
            print("------ BLUENET_LIB_NAV: location Denied")
        case .AuthorizedAlways:
            print("------ BLUENET_LIB_NAV: location AuthorizedAlways")
            start()
        case .AuthorizedWhenInUse:
            print("------ BLUENET_LIB_NAV: location AuthorizedWhenInUse")
            showLocationAlert()
        }
    }
    
    
    public func locationManager(manager : CLLocationManager, didStartMonitoringForRegion region : CLRegion) {
        print("------ BLUENET_LIB_NAV: did start MONITORING \(region) \n");
    }
    
    public func locationManager(manager : CLLocationManager, didRangeBeacons beacons : [CLBeacon], inRegion region: CLBeaconRegion) {
//        print ("Did Range:")
//        for beacon in beacons {
//            print("\(beacon)")
//        }
//        print(" ")
        var iBeacons = [iBeaconPacket]()
        
        for beacon in beacons {
            if (beacon.rssi < -1) {
                iBeacons.append(iBeaconPacket(
                    uuid: beacon.proximityUUID.UUIDString,
                    major: beacon.major,
                    minor: beacon.minor,
                    rssi: beacon.rssi,
                    referenceId: region.identifier
                ))
            }
        }
        
        if (iBeacons.count > 0) {
            self.eventBus.emit("iBeaconAdvertisement", iBeacons)
        }
    }
    
    public func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("did enter region \(region) \n");
        self._startRanging(region);
    }
    
    
    public func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("did exit region \(region) \n");
        self._stopRanging(region);
    }
    
    // this is a fallback mechanism because the enter and exit do not always fire.
    public func locationManager(manager: CLLocationManager, didDetermineState state: CLRegionState, forRegion region: CLRegion) {
        print("State change \(state.rawValue) , \(region)")
        if (state.rawValue == 1) {
            self._startRanging(region)
        }
        else { // 0 == unknown, 2 is outside
            self._stopRanging(region)
        }
    }
    
    
    
    /*
     *  locationManager:rangingBeaconsDidFailForRegion:withError:
     *
     *  Discussion:
     *    Invoked when an error has occurred ranging beacons in a region. Error types are defined in "CLError.h".
     */

    public func locationManager(manager: CLLocationManager, rangingBeaconsDidFailForRegion region: CLBeaconRegion, withError error: NSError) {
         print("------ BLUENET_LIB_NAV: did rangingBeaconsDidFailForRegion \(region)  withError: \(error) \n");
    }
    
    

    /*
     *  locationManager:didFailWithError:
     *
     *  Discussion:
     *    Invoked when an error has occurred. Error types are defined in "CLError.h".
     */
  
    public func locationManager(manager: CLLocationManager, didFailWithError error: NSError){
        print("------ BLUENET_LIB_NAV: did didFailWithError withError: \(error) \n");
    }
    
    /*
     *  locationManager:monitoringDidFailForRegion:withError:
     *
     *  Discussion:
     *    Invoked when a region monitoring error has occurred. Error types are defined in "CLError.h".
     */
 
    public func locationManager(manager: CLLocationManager, monitoringDidFailForRegion region: CLRegion?, withError error: NSError){
        print("------ BLUENET_LIB_NAV: did monitoringDidFailForRegion \(region)  withError: \(error) \n");
    }
    

    
    
    
    
    // MARK: util
    // -------------------- UITL -------------------------//
    
    
    func _beaconInList(beacon: iBeaconContainer, list: [iBeaconContainer]) -> Bool {
        for element in list {
            if (element.UUID == beacon.UUID) {
                return true;
            }
        }
        return false;
    }

    func _startRanging(region: CLRegion) {
        self.eventBus.emit("lowLevelEnterRegion", region.identifier)
        
        for element in self.trackingBeacons {
//            print ("------ BLUENET_LIB_NAV: region id \(region.identifier) vs elementId \(element.region.identifier) \n")
            if (element.region.identifier == region.identifier) {
                print ("------ BLUENET_LIB_NAV: startRanging")
                self.manager.startRangingBeaconsInRegion(element.region)
            }
        }
    }
    
    func _stopRanging(region: CLRegion) {
        self.eventBus.emit("lowLevelExitRegion", region.identifier)
        
        for element in self.trackingBeacons {
//            print ("------ BLUENET_LIB_NAV: region id \(region.identifier) vs elementId \(element.region.identifier) \n")
            if (element.region.identifier == region.identifier) {
                print ("------ BLUENET_LIB_NAV: stopRanging!")
                self.manager.stopRangingBeaconsInRegion(element.region)
            }
        }
    }

}
