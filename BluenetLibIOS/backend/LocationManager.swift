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

open class LocationManager : NSObject, CLLocationManagerDelegate {
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
    
    open func trackBeacon(_ beacon: iBeaconContainer) {
        if (!self._beaconInList(beacon, list: self.trackingBeacons)) {
            trackingBeacons.append(beacon);
            if (self.started == true) {
                self.manager.startMonitoring(for: beacon.region)
                self.manager.requestState(for: beacon.region)
            }
        }
        
        self.start();
    }
    
    open func check() {
        self.locationManager(self.manager, didChangeAuthorization: CLLocationManager.authorizationStatus())
    }
    
    open func stopTrackingAllRegions() {
        // stop monitoring all previous regions
        for region in self.manager.monitoredRegions {
            print ("------ BLUENET_LIB_NAV: INITIALIZATION: stop monitoring old region: \(region)")
            self.manager.stopMonitoring(for: region)
        }
    }
    
    open func clearTrackedBeacons() {
        self.pauseTrackingIBeacons()
        self.trackingBeacons.removeAll()
    }
    
    open func stopTrackingIBeacon(_ uuid: String) {
        // stop monitoring this beacon
        var targetIndex : Int? = nil;
        let uuidObject = UUID(uuidString : uuid)
        if (uuidObject == nil) {
            return
        }
        
        let uuidString = uuidObject!.uuidString
        for (index, beacon) in self.trackingBeacons.enumerated() {
            if (beacon.UUID.uuidString == uuidString) {
                self.manager.stopRangingBeacons(in: beacon.region)
                self.manager.stopMonitoring(for: beacon.region)
                targetIndex = index;
                break
            }
        }

        if (targetIndex != nil) {
            self.trackingBeacons.remove(at: targetIndex!)
            if (self.trackingBeacons.count == 0) {
                self.trackingState = false
            }
        }
        
    }
    
    open func pauseTrackingIBeacons() {
        // stop monitoring all becons
        for beacon in self.trackingBeacons {
            self.manager.stopRangingBeacons(in: beacon.region)
            self.manager.stopMonitoring(for: beacon.region)
        }
        self.trackingState = false
    }
    
    open func isTracking() -> Bool {
        return self.trackingState
    }
    
    open func startTrackingIBeacons() {
        // reinitialize
        for beacon in self.trackingBeacons {
            self.manager.startMonitoring(for: beacon.region)
            self.manager.requestState(for: beacon.region)
        }
    }
    
    func resetBeaconRanging() {
        print ("------ BLUENET_LIB_NAV: Resetting ibeacon tracking")
        self.pauseTrackingIBeacons()
        self.startTrackingIBeacons()
        self.trackingState = true
    }
    
    func start() {
        self.manager.startUpdatingLocation()
        if (self.manager.responds(to: #selector(getter: CLLocationManager.allowsBackgroundLocationUpdates))) {
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
    
    open func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch (CLLocationManager.authorizationStatus()) {
        case .notDetermined:
            print("------ BLUENET_LIB_NAV: location NotDetermined")
            /*
             First you need to add NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription(if you want to use in background) in your info.plist file OF THE PROGRAM THAT IMPLEMENTS THIS!
             */
            manager.requestAlwaysAuthorization()
        case .restricted:
            print("------ BLUENET_LIB_NAV: location Restricted")
        case .denied:
            showLocationAlert()
            print("------ BLUENET_LIB_NAV: location Denied")
        case .authorizedAlways:
            print("------ BLUENET_LIB_NAV: location AuthorizedAlways")
            start()
        case .authorizedWhenInUse:
            print("------ BLUENET_LIB_NAV: location AuthorizedWhenInUse")
            showLocationAlert()
        }
    }
    
    
    open func locationManager(_ manager : CLLocationManager, didStartMonitoringFor region : CLRegion) {
        print("------ BLUENET_LIB_NAV: did start MONITORING \(region) \n");
    }
    
    open func locationManager(_ manager : CLLocationManager, didRangeBeacons beacons : [CLBeacon], in region: CLBeaconRegion) {
//        print ("Did Range:")
//        for beacon in beacons {
//            print("\(beacon)")
//        }
//        print(" ")
        var iBeacons = [iBeaconPacket]()
        
        for beacon in beacons {
            if (beacon.rssi < -1) {
                iBeacons.append(iBeaconPacket(
                    uuid: beacon.proximityUUID.uuidString,
                    major: beacon.major,
                    minor: beacon.minor,
                    distance: NSNumber(value: beacon.accuracy),
                    rssi: NSNumber(value: beacon.rssi),
                    referenceId: region.identifier
                ))
            }
        }
        
        if (iBeacons.count > 0) {
            self.eventBus.emit("iBeaconAdvertisement", iBeacons)
        }
    }
    
    open func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("------ BLUENET_LIB_NAV: did enter region \(region) \n");
        self._startRanging(region);
    }
    
    
    open func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("------ BLUENET_LIB_NAV: did exit region \(region) \n");
        self._stopRanging(region);
    }
    
    // this is a fallback mechanism because the enter and exit do not always fire.
    open func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        print("------ BLUENET_LIB_NAV: State change \(state.rawValue) , \(region)")
        if (state.rawValue == 1) {       // 1 == inside
            self._startRanging(region)
        }
        else if (state.rawValue == 2) {  // 2 == outside
            self._stopRanging(region)
        }
        else {                           // 0 == unknown,
           self._stopRanging(region)
        }
    }
    
    
    
    /*
     *  locationManager:rangingBeaconsDidFailForRegion:withError:
     *
     *  Discussion:
     *    Invoked when an error has occurred ranging beacons in a region. Error types are defined in "CLError.h".
     */

    open func locationManager(_ manager: CLLocationManager, rangingBeaconsDidFailFor region: CLBeaconRegion, withError error: Error) {
         print("------ BLUENET_LIB_NAV: did rangingBeaconsDidFailForRegion \(region)  withError: \(error) \n");
    }
    
    

    /*
     *  locationManager:didFailWithError:
     *
     *  Discussion:
     *    Invoked when an error has occurred. Error types are defined in "CLError.h".
     */
  
    open func locationManager(_ manager: CLLocationManager, didFailWithError error: Error){
        print("------ BLUENET_LIB_NAV: did didFailWithError withError: \(error) \n");
    }
    
    /*
     *  locationManager:monitoringDidFailForRegion:withError:
     *
     *  Discussion:
     *    Invoked when a region monitoring error has occurred. Error types are defined in "CLError.h".
     */
 
    open func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error){
        print("------ BLUENET_LIB_NAV: did monitoringDidFailForRegion \(region)  withError: \(error) \n");
    }
    

    
    
    
    
    // MARK: util
    // -------------------- UITL -------------------------//
    
    
    func _beaconInList(_ beacon: iBeaconContainer, list: [iBeaconContainer]) -> Bool {
        for element in list {
            if (element.UUID == beacon.UUID) {
                return true;
            }
        }
        return false;
    }

    func _startRanging(_ region: CLRegion) {
        self.eventBus.emit("lowLevelEnterRegion", region.identifier)
        
        for element in self.trackingBeacons {
//            print ("------ BLUENET_LIB_NAV: region id \(region.identifier) vs elementId \(element.region.identifier) \n")
            if (element.region.identifier == region.identifier) {
                print ("------ BLUENET_LIB_NAV: startRanging")
                self.manager.startRangingBeacons(in: element.region)
            }
        }
    }
    
    func _stopRanging(_ region: CLRegion) {
        self.eventBus.emit("lowLevelExitRegion", region.identifier)
        
        for element in self.trackingBeacons {
//            print ("------ BLUENET_LIB_NAV: region id \(region.identifier) vs elementId \(element.region.identifier) \n")
            if (element.region.identifier == region.identifier) {
                print ("------ BLUENET_LIB_NAV: stopRanging!")
                self.manager.stopRangingBeacons(in: element.region)
            }
        }
    }

}
