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
    var manager : CLLocationManager?
    
    var eventBus : EventBus!
    var trackingBeacons = [iBeaconContainer]()
    var appName = "Crownstone"
    var started = false
    var startedStateBackground = true
    var trackingState = false
    
    var backgroundEnabled = false
    
    // cache for the location
    var coordinates = CLLocationCoordinate2D()
    
    public init(eventBus: EventBus, backgroundEnabled: Bool = false) {
        super.init()
        
        self.eventBus = eventBus
        self.backgroundEnabled = backgroundEnabled
        
        LOG.info("BLUENET_LIB_NAV: location services enabled: \(CLLocationManager.locationServicesEnabled())");
        LOG.info("BLUENET_LIB_NAV: ranging services enabled: \(CLLocationManager.isRangingAvailable())");

    }
    
    open func setBackgroundScanning(newBackgroundState: Bool) {
        if (self.backgroundEnabled == newBackgroundState) {
            return
        }
        self.backgroundEnabled = newBackgroundState
        self.requestLocationPermission()
    }
    

    
    open func requestLocation() -> CLLocationCoordinate2D {
        // ask for permission if the manager does not exist and create the manager
        if (self.manager == nil) { self.requestLocationPermission() }
        
        return coordinates
    }
    
    func setLocationManager() {
        if (Thread.isMainThread == true) {
            LOG.info("BLUENET_LIB_NAV: requestLocationPermission, Creating CLLocationManager");
            self.manager = CLLocationManager()
            self.manager!.delegate = self
            self.stopTrackingAllRegions()
        }
        else {
            DispatchQueue.main.sync{
                LOG.info("BLUENET_LIB_NAV: requestLocationPermission, Creating CLLocationManager");
                self.manager = CLLocationManager()
                self.manager!.delegate = self
                self.stopTrackingAllRegions()
            }
        }
    }
    
    open func requestLocationPermission() {
        LOG.info("BLUENET_LIB_NAV: INITIALIZATION: stop monitoring old region")
        if (self.manager == nil) {
            self.setLocationManager()
        }
        
        LOG.info("BLUENET_LIB_NAV: Requesting permission from requestLocationPermission")
        if (Thread.isMainThread == true) {
            self.locationManager(self.manager!, didChangeAuthorization: CLLocationManager.authorizationStatus())
        }
        else {
            DispatchQueue.main.sync{
                self.locationManager(self.manager!, didChangeAuthorization: CLLocationManager.authorizationStatus())
            }
        }
    }
    
    
    open func trackBeacon(_ beacon: iBeaconContainer) {
        // ask for permission if the manager does not exist and create the manager
        if (self.manager == nil) { self.requestLocationPermission() }
        
        if (!self._beaconInList(beacon, list: self.trackingBeacons)) {
            trackingBeacons.append(beacon);
            if (self.started == true) {
                self.manager!.startMonitoring(for: beacon.region)
                self.manager!.requestState(for: beacon.region)
            }
        }
        
        if (self.started == false) {
            self.start();
        }
    }

    
    open func refreshLocation() {
        // ask for permission if the manager does not exist and create the manager
        if (self.manager == nil) { self.requestLocationPermission() }
        
        for region in self.manager!.monitoredRegions {
            self.manager!.requestState(for: region)
        }
    }
    
    open func stopTrackingAllRegions() {
        // ask for permission if the manager does not exist and create the manager
        if (self.manager == nil) { self.requestLocationPermission() }
        
        // stop monitoring all previous regions
        for region in self.manager!.monitoredRegions {
            LOG.info("BLUENET_LIB_NAV: INITIALIZATION: stop monitoring old region: \(region)")
            self.manager!.stopMonitoring(for: region)
        }
    }
    
    open func clearTrackedBeacons() {
        self.pauseTrackingIBeacons()
        self.trackingBeacons.removeAll()
    }
    
    open func stopTrackingIBeacon(_ uuid: String) {
        // ask for permission if the manager does not exist and create the manager
        if (self.manager == nil) { self.requestLocationPermission() }
        
        // stop monitoring this beacon
        var targetIndex : Int? = nil;
        let uuidObject = UUID(uuidString : uuid)
        if (uuidObject == nil) {
            return
        }
        
        let uuidString = uuidObject!.uuidString
        for (index, beacon) in self.trackingBeacons.enumerated() {
            if (beacon.UUID.uuidString == uuidString) {
                self.manager!.stopRangingBeacons(in: beacon.region)
                self.manager!.stopMonitoring(for: beacon.region)
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
        // ask for permission if the manager does not exist and create the manager
        if (self.manager == nil) {
            LOG.info("BLUENET_LIB_NAV: Requesting permission from pauseTrackingIBeacons")
            self.requestLocationPermission()
        }
        
        // stop monitoring all becons
        for beacon in self.trackingBeacons {
            self.manager!.stopRangingBeacons(in: beacon.region)
            self.manager!.stopMonitoring(for: beacon.region)
        }
        self.trackingState = false
    }
    
    open func isTracking() -> Bool {
        return self.trackingState
    }
    
    open func startTrackingIBeacons() {
        // ask for permission if the manager does not exist and create the manager
        if (self.manager == nil) { self.requestLocationPermission() }
        
        // reinitialize
        for beacon in self.trackingBeacons {
            self.manager!.startMonitoring(for: beacon.region)
            self.manager!.requestState(for: beacon.region)
        }
    }
    
    func resetBeaconRanging() {
        LOG.info("BLUENET_LIB_NAV: Resetting ibeacon tracking")
        self.pauseTrackingIBeacons()
        self.startTrackingIBeacons()
        self.trackingState = true
    }
    
    func start() {
        if (self.backgroundEnabled == false) {
            self.startWithoutBackground()
            return
        }

        LOG.info("BLUENET_LIB_NAV: Start called")
        // ask for permission if the manager does not exist and create the manager
        if (self.manager == nil) { self.requestLocationPermission() }
        
        self.manager!.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        self.manager!.pausesLocationUpdatesAutomatically = true
        self.manager!.startUpdatingLocation()
        if (self.manager!.responds(to: #selector(getter: CLLocationManager.allowsBackgroundLocationUpdates))) {
            LOG.info("BLUENET_LIB_NAV: Manager allows background location updates. We enable it.")
            self.manager!.allowsBackgroundLocationUpdates = true
        }
        
        self.resetBeaconRanging();
        self.started = true
        self.startedStateBackground = false
    }
    
    func startWithoutBackground() {
        LOG.info("BLUENET_LIB_NAV: startWithoutBackground called")
        // ask for permission if the manager does not exist and create the manager
        if (self.manager == nil) {
            LOG.info("BLUENET_LIB_NAV: Requesting permission from startWithoutBackground")
            self.requestLocationPermission()
        }
        
        // This will reset the location manager if required. Once a location manager has received background permission, we cannot unset it.
        if (self.startedStateBackground == false) {
            self.startedStateBackground = true
            LOG.info("BLUENET_LIB_NAV: Resetting the location manager")
            
            // Setting the location manager will trigger a cycle of location permission -> start so we return this start method after setting the location manager.
            self.setLocationManager()
            return
        }
        
        self.manager!.pausesLocationUpdatesAutomatically = true
        self.manager!.startUpdatingLocation()
        if (self.manager!.responds(to: #selector(getter: CLLocationManager.allowsBackgroundLocationUpdates))) {
            LOG.info("BLUENET_LIB_NAV: Manager allows background location updates. we disable it.")
            self.manager!.allowsBackgroundLocationUpdates = false
        }
        
        self.resetBeaconRanging();
        self.started = true
    }
    
    open func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        LOG.info("BLUENET_LIB_NAV: Changed AuthorizationL \(status)")
        switch (CLLocationManager.authorizationStatus()) {
            case .notDetermined:
                LOG.info("BLUENET_LIB_NAV: location NotDetermined")
                /*
                 First you need to add NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription(if you want to use in background) in your info.plist file OF THE PROGRAM THAT IMPLEMENTS THIS!
                 */
                
                // when just requesting in use, iBeacon permission is DENIED! We need ALWAYS!
                manager.requestAlwaysAuthorization()

                self.eventBus.emit("locationStatus", "unknown");
            case .restricted:
                LOG.info("BLUENET_LIB_NAV: location Restricted")
                self.eventBus.emit("locationStatus", "off");
            case .denied:
                LOG.info("BLUENET_LIB_NAV: location Denied")
                self.eventBus.emit("locationStatus", "off");
                showLocationAlert()
            case .authorizedAlways:
                LOG.info("BLUENET_LIB_NAV: location AuthorizedAlways")
                self.eventBus.emit("locationStatus", "on");
                start()
            case .authorizedWhenInUse:
                LOG.info("BLUENET_LIB_NAV: location AuthorizedWhenInUse")
                self.eventBus.emit("locationStatus", "foreground");
                manager.requestAlwaysAuthorization()
                showLocationAlert()
        }
    }
    
    
    open func locationManager(_ manager : CLLocationManager, didStartMonitoringFor region : CLRegion) {
        LOG.info("BLUENET_LIB_NAV: did start MONITORING \(region) \n");
    }
        
    
    open func locationManager(_ manager : CLLocationManager, didRangeBeacons beacons : [CLBeacon], in region: CLBeaconRegion) {
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
        LOG.info("BLUENET_LIB_NAV: did enter region \(region) \n");
        self._startRanging(region);
    }
    
    
    open func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        LOG.info("BLUENET_LIB_NAV: did exit region \(region) \n");
        self._stopRanging(region);
    }
    
    // this is a fallback mechanism because the enter and exit do not always fire.
    open func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        LOG.info("BLUENET_LIB_NAV: State change \(state.rawValue) , \(region)")
        if (state.rawValue == 1) {       // 1 == inside
            self._startRanging(region)
        }
        else if (state.rawValue == 2) {  // 2 == outside
            self._stopRanging(region)
        }
        else {                           // 0 == unknown,
           // self._stopRanging(region)
        }
    }
    
    
    
    /*
     *  locationManager:rangingBeaconsDidFailForRegion:withError:
     *
     *  Discussion:
     *    Invoked when an error has occurred ranging beacons in a region. Error types are defined in "CLError.h".
     */

    open func locationManager(_ manager: CLLocationManager, rangingBeaconsDidFailFor region: CLBeaconRegion, withError error: Error) {
         LOG.error("BLUENET_LIB_NAV: did rangingBeaconsDidFailForRegion \(region)  withError: \(error) \n");
    }
    
    

    /*
     *  locationManager:didFailWithError:
     *
     *  Discussion:
     *    Invoked when an error has occurred. Error types are defined in "CLError.h".
     */
  
    open func locationManager(_ manager: CLLocationManager, didFailWithError error: Error){
        LOG.error("BLUENET_LIB_NAV: did didFailWithError withError: \(error) \n");
    }
    
    /*
     *  locationManager:monitoringDidFailForRegion:withError:
     *
     *  Discussion:
     *    Invoked when a region monitoring error has occurred. Error types are defined in "CLError.h".
     */
    open func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error){
        LOG.error("BLUENET_LIB_NAV: did monitoringDidFailForRegion \(String(describing: region))  withError: \(error)\n");
    }
    

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            LOG.verbose("BLUENET_LIB_NAV: update user's location: \(location.coordinate)")
            coordinates = location.coordinate
        }
    }
    
    
    
    
    // MARK: util
    // --------------UITL -------------------------//
    
    
    func _beaconInList(_ beacon: iBeaconContainer, list: [iBeaconContainer]) -> Bool {
        for element in list {
            if (element.UUID == beacon.UUID) {
                return true;
            }
        }
        return false;
    }

    func _startRanging(_ region: CLRegion) {
        // ask for permission if the manager does not exist and create the manager
        if (self.manager == nil) { self.requestLocationPermission() }
        
        for element in self.manager!.rangedRegions {
            if (element.identifier == region.identifier) {
                return
            }
        }
        
        self.eventBus.emit("lowLevelEnterRegion", region.identifier)
        for element in self.trackingBeacons {
            if (element.region.identifier == region.identifier) {
                LOG.info("BLUENET_LIB_NAV: startRanging region \(region.identifier)")
                self.manager!.startRangingBeacons(in: element.region)
            }
        }
    }
    
    func _stopRanging(_ region: CLRegion) {
        // ask for permission if the manager does not exist and create the manager
        if (self.manager == nil) { self.requestLocationPermission() }
        
        var abort = true
        for element in self.manager!.rangedRegions {
            if (element.identifier == region.identifier) {
                abort = false
            }
        }
        
        if (abort) {
            return
        }
        
        self.eventBus.emit("lowLevelExitRegion", region.identifier)
        
        for element in self.trackingBeacons {
            if (element.region.identifier == region.identifier) {
                LOG.info("BLUENET_LIB_NAV: stopRanging region \(region.identifier)!")
                self.manager!.stopRangingBeacons(in: element.region)
            }
        }
    }

}
