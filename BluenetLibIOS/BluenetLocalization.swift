//
//  BluenetNavigation.swift
//  BluenetLibIOS
//
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

public class Fingerprint {
    var data = [String: [NSNumber]]()
    
    func collect(ibeaconData: [iBeaconPacket]) {
        for point in ibeaconData {
            // we claim that the uuid, major and minor combination is unique.
            
            if (data.indexForKey(point.idString) == nil) {
                data[point.idString] = [NSNumber]()
            }
            
            data[point.idString]!.append(point.rssi)
        }
    }
}

public class BluenetLocalization {
    public var locationManager : LocationManager!
    let eventBus : EventBus!
    
    var classifier = [String: LocationClassifier]()
    var collectingFingerprint : Fingerprint?
    var collectingCallbackId : Int?
    var activeGroup : String?
    var activeLocation : String?
    
    var fingerprintData = [String : [String : Fingerprint]]() // groupId: locationId: Fingerprint
    
    
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
    
    public func reset() {
        self.eventBus.reset()
        for (location, classifier) in self.classifier {
            classifier.reset()
        }
    }
    
    public func loadFingerprint(groupId: String, locationId: String, fingerprint: Fingerprint) {
        self._loadFingerprint(groupId, locationId: locationId, fingerprint: fingerprint)
    }
    
    public func getFingerprint(groupId: String, locationId: String) -> Fingerprint? {
        if let groupFingerprints = self.fingerprintData[groupId] {
            if let returnPrint = groupFingerprints[locationId] {
                return returnPrint
            }
        }
        return nil
    }
    
    func _loadFingerprint(groupId: String, locationId: String, fingerprint: Fingerprint) {
        if (self.classifier[groupId] == nil) {
            self.classifier[groupId] = LocationClassifier()
        }
        self.classifier[groupId]!.loadFingerprint(locationId, fingerprint: fingerprint)
    }
    
    public func startCollectingFingerprint() {
        self.collectingFingerprint = Fingerprint()
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
    
    public func abortCollectingFingerprint() {
        self._cleanupCollectingFingerprint()
    }
   
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
    
    func _cleanupCollectingFingerprint() {
        if let callbackId = self.collectingCallbackId {
            self.off(callbackId)
        }
        self.collectingCallbackId = nil
        self.collectingFingerprint = nil
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
            
            // create classifiers for this group if required.
            if (self.classifier[self.activeGroup!] == nil) {
                self.classifier[self.activeGroup!] = LocationClassifier()
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
        var location = self.classifier[self.activeGroup!]!.predict(data)
        self.eventBus.emit("currentLocation", location)
        return location
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