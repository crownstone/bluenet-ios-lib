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


public class BeaconID {
    var UUID : NSUUID;
    var id = ""
    var region : CLBeaconRegion;
    
    public init(id: String, uuid: String) {
        self.UUID = NSUUID(UUIDString : uuid)!;
        self.id = id;
        self.region = CLBeaconRegion(proximityUUID: self.UUID, identifier: self.id);
    }
}

public class iBeaconPacket {
    public var uuid : String
    public var major: NSNumber
    public var minor: NSNumber
    public var rssi : NSNumber
    public var idString: String
    
    init(uuid: String, major: NSNumber, minor: NSNumber, rssi: NSNumber) {
        self.uuid = uuid
        self.major = major
        self.minor = minor
        self.rssi = rssi
        self.idString = uuid + String(major) + String(minor)
    }
    
    func toJSON() -> JSON {
        var dataDict = [String : AnyObject]()
        dataDict["id"]    = self.idString
        dataDict["uuid"]  = self.uuid
        dataDict["major"] = self.major
        dataDict["minor"] = self.minor
        dataDict["rssi"]  = self.rssi
        
        var dataJSON = JSON(dataDict)
        
        return dataJSON
    }
}

public class LocationManager : NSObject, CLLocationManagerDelegate {
    var manager : CLLocationManager!
    
    var eventBus : EventBus!
    var trackingBeacons = [BeaconID]()
    var appName = "Crownstone"
    var started = false;

    
    public init(eventBus: EventBus) {
        super.init();
        
        self.eventBus = eventBus;
        
        print("Starting location manager")
        self.manager = CLLocationManager()
        self.manager.delegate = self;
        
        print("location services enabled: \(CLLocationManager.locationServicesEnabled())");
        print("ranging services enabled: \(CLLocationManager.isRangingAvailable())");
        
        // stop monitoring all previous regions
        for region in self.manager.monitoredRegions {
            print ("INITIALIZATION: stop monitoring: \(region)")
            self.manager.stopMonitoringForRegion(region)
        }
        

        self.check()
    }
    
    public func trackBeacon(beacon: BeaconID) {
        if (!self._beaconInList(beacon, list: self.trackingBeacons)) {
            trackingBeacons.append(beacon);
            self.manager.startMonitoringForRegion(beacon.region)
            self.manager.requestStateForRegion(beacon.region)
        }
        
        if (self.started == false) {
            self.start();
        }
    }
    
    public func check() {
        self.locationManager(self.manager, didChangeAuthorizationStatus: CLLocationManager.authorizationStatus())
    }
    
    
    
    func start() {
        print("starting!")
        self.manager.startUpdatingLocation()
        if (self.manager.respondsToSelector("allowsBackgroundLocationUpdates")) {
            self.manager.allowsBackgroundLocationUpdates = true
        }
        self.started = true
    }
    
    public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch (CLLocationManager.authorizationStatus()) {
        case .NotDetermined:
            print("NotDetermined")
            /*
             First you need to add NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription(if you want to use in background) in your info.plist file OF THE PROGRAM THAT IMPLEMENTS THIS!
             */
            manager.requestAlwaysAuthorization()
        case .Restricted:
            print("Restricted")
        case .Denied:
            showLocationAlert()
            print("Denied")
        case .AuthorizedAlways:
            print("AuthorizedAlways")
            start()
        case .AuthorizedWhenInUse:
            print("AuthorizedWhenInUse")
            showLocationAlert()
        }
    }
    
    
    public func locationManager(manager : CLLocationManager, didStartMonitoringForRegion region : CLRegion) {
        print("did start MONITORING \(region) \n");
    }
    
    public func locationManager(manager : CLLocationManager, didRangeBeacons beacons : [CLBeacon], inRegion region: CLBeaconRegion) {

        var iBeacons = [iBeaconPacket]()
        
        for beacon in beacons {
            iBeacons.append(iBeaconPacket(
                uuid: beacon.proximityUUID.UUIDString,
                major: beacon.major,
                minor: beacon.minor,
                rssi: beacon.rssi
            ))
        }
        
        self.eventBus.emit("iBeaconAdvertisement", iBeacons)
        
    }
    
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("did enter region \(region) \n");
        self._startRanging(region);
    }
    
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
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
    
    
    
    
    
    
    
    
    // MARK: util
    // -------------------- UITL -------------------------//
    
    
    func _beaconInList(beacon: BeaconID, list: [BeaconID]) -> Bool {
        for element in list {
            if (element.UUID == beacon.UUID) {
                return true;
            }
        }
        return false;
    }
    
    func _startRanging(region: CLRegion) {
        self.eventBus.emit("enterRegion", region.identifier)
        
        for element in self.trackingBeacons {
            print ("region id \(region.identifier) vs elementId \(element.region.identifier) \n")
            if (element.region.identifier == region.identifier) {
                print ("startRanging")
                self.manager.startRangingBeaconsInRegion(element.region)
            }
        }
    }
    
    func _stopRanging(region: CLRegion) {
        self.eventBus.emit("exitRegion", region.identifier)
        
        for element in self.trackingBeacons {
            print ("region id \(region.identifier) vs elementId \(element.region.identifier) \n")
            if (element.region.identifier == region.identifier) {
                print ("stopRanging!")
                self.manager.stopRangingBeaconsInRegion(element.region)
            }
        }
    }

}
