//
//  BluenetNavigation.swift
//  BluenetLibIOS
//
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

public class FingerPrint {
    var data = [String: [NSNumber]]()
    
    func collect(ibeaconData: [iBeaconPacket]) {
        for point in ibeaconData {
            // we claim that the uuid, major and minor combination is unique.
            let idString = point.uuid + String(point.major) + String(point.minor)
            if (data.indexForKey(idString) == nil) {
                data[idString] = [NSNumber]()
            }
            
            data[idString]!.append(point.rssi)
        }
    }
}

public class BluenetLocalization {
    var locationManager : LocationManager!
    let eventBus : EventBus!
    
    var classifier = [String: LocationClassifier]()
    var collectingFingerPrint : FingerPrint?
    var collectingCallbackId : Int?
    var collectingLocation : String?
    var activeGroup : String?
    var activeLocation : String?
    
    var fingerPrintData = [String : [String : FingerPrint]]() // groupId: locationId: fingerprint
    
    
    public init(appName: String) {
        self.eventBus = EventBus()
        self.locationManager = LocationManager(eventBus: self.eventBus)

        self.eventBus.on("iBeaconAdvertisement", self.updateState);
        APPNAME = appName
    }
    
    public init() {
        self.eventBus = EventBus()
        self.locationManager = LocationManager(eventBus: self.eventBus)
        self.eventBus.on("iBeaconAdvertisement", self.updateState);
    }
    
    public func trackUUID(uuid: String, groupName: String) {
        let trackStone = BeaconID(id: groupName, uuid: uuid)
        self.locationManager.trackBeacon(trackStone)
    }
        
    public func on(topic: String, _ callback: (AnyObject) -> Void) -> Int {
        return self.eventBus.on(topic, callback)
    }
    
    public func off(id: Int) {
        self.eventBus.off(id);
    }
    
    public func loadFingerPrint(groupId: String, locationId: String, fingerPrint: FingerPrint) {
        self._loadFingerPrint(groupId, locationId: locationId, fingerPrint: fingerPrint)
    }
    
    func _loadFingerPrint(groupId: String, locationId: String, fingerPrint: FingerPrint) {
        if (self.classifier[groupId] == nil) {
            self.classifier[groupId] = LocationClassifier()
        }
        self.classifier[groupId]!.loadFingerPrint(locationId, fingerPrint: fingerPrint)
    }
    
    public func startCollectingFingerprint(locationId: String, groupId: String) {
        self.collectingFingerPrint = FingerPrint()
        self.collectingLocation = locationId
        self.collectingCallbackId = self.eventBus.on("iBeaconAdvertisement", {ibeaconData in
            if let data = ibeaconData as? [iBeaconPacket] {
                if let fingerPrint = self.collectingFingerPrint {
                    fingerPrint.collect(data)
                }
                else {
                    self._cleanupCollectingFingerPrint()
                }
            }
        });
    }
   
    public func finishCollectingFingerprint() {
        if let activeGroup = self.activeGroup {
            if (self.collectingFingerPrint != nil && self.collectingLocation != nil) {
                if (self.fingerPrintData[activeGroup] == nil) {
                    self.fingerPrintData[activeGroup] = [String: FingerPrint]()
                }
                self.fingerPrintData[activeGroup]![self.collectingLocation!] = self.collectingFingerPrint!
                self._loadFingerPrint(activeGroup, locationId: self.collectingLocation!, fingerPrint: self.collectingFingerPrint!)
            }
        }
        self._cleanupCollectingFingerPrint()
    }
    
    func _cleanupCollectingFingerPrint() {
        if let callbackId = self.collectingCallbackId {
            self.off(callbackId)
        }
        self.collectingCallbackId = nil
        self.collectingFingerPrint = nil
        self.collectingLocation = nil
    }
    
    func updateState(ibeaconData: AnyObject) {
        if let data = ibeaconData as? [iBeaconPacket] {
            if (self.activeGroup != data[0].uuid) {
                if (self.activeGroup != nil) {
                    self.eventBus.emit("exitRegion", self.activeGroup!)
                }
                self.activeGroup = data[0].uuid
                self.eventBus.emit("enterRegion", self.activeGroup!)
            }
            
            var currentlocation = self.getLocation(data)
            if (self.activeLocation != currentlocation) {
                if (self.activeLocation != nil) {
                    self.eventBus.emit("exitLocation", self.activeLocation!)
                }
                self.activeLocation = currentlocation
                self.eventBus.emit("enterLocation", self.activeLocation!)
            }
        }
    }
    
    func getLocation(data : [iBeaconPacket]) -> String {
        // LOCATION algorithm here
        
        self.eventBus.emit("locationUpdate", "location")
        return "bla"
    }

   
}


/**
 * This will show an alert about location and forward the user to the settings page
 **/
func showLocationAlert() {
    let alertController = UIAlertController(title: "Allow \(APPNAME) to use your location",
                                            message: "The location permission was not authorized. Please set it to \"Always\" in Settings to continue.",
                                            preferredStyle: .Alert)
    
    let settingsAction = UIAlertAction(title: "Settings", style: .Default) { (alertAction) in
        // THIS IS WHERE THE MAGIC HAPPENS!!!! It triggers the settings page to change the permissions
        if let appSettings = NSURL(string: UIApplicationOpenSettingsURLString) {
            UIApplication.sharedApplication().openURL(appSettings)
        }
    }
    alertController.addAction(settingsAction)
    
    let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
    alertController.addAction(cancelAction)
    
    VIEWCONTROLLER!.presentViewController(alertController, animated: true, completion: nil)
}