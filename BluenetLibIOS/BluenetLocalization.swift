//
//  BluenetNavigation.swift
//  BluenetLibIOS
//
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import UIKit

public class BluenetLocalization {
    var locationManager : LocationManager!
    let eventBus : EventBus!
    
    public init(appName: String) {
        self.eventBus = EventBus()
        self.locationManager = LocationManager(eventBus: self.eventBus)
        APPNAME = appName
        // let guideStone = BeaconID(id: "dobeacon",uuid: "a643423e-e175-4af0-a2e4-31e32f729a8a");
    }
    
    public init() {
        self.eventBus = EventBus()
        self.locationManager = LocationManager(eventBus: self.eventBus)
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