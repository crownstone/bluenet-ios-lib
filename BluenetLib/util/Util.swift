//
//  util.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 24/05/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth
import PromiseKit

/**
 * Delay a callback
 * there is an inherent delay in this method of around 40 - 150 ms
 *
 * @param delay = delay in seconds
 */
public func delay(_ delay: Double, _ closure: @escaping ()->(Void)) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}



#if os(iOS)
/**
 * This will show an alert about location and forward the user to the settings page
 **/
public func showLocationAlert() {
    let alertController = UIAlertController(title: "Allow \(APPNAME) to use your location",
                                            message: "The location permission was not authorized. Please set it to \"Always\" in Settings to continue. You can choose to use the continuous background events in the app, but the permission is required in order to use the Crownstones.",
                                            preferredStyle: .alert)
    
    let settingsAction = UIAlertAction(title: "Settings", style: .default) { (alertAction) in
        // THIS IS WHERE THE MAGIC HAPPENS!!!! It triggers the settings page to change the permissions
        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.openURL(appSettings)
        }
    }
    alertController.addAction(settingsAction)
    
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    alertController.addAction(cancelAction)
    
    VIEWCONTROLLER!.present(alertController, animated: true, completion: nil)
}

#endif

/**
 *
 **/
public func getUUID() -> String {
    return UUID().uuidString
}


public func getServiceFromList(_ list: [CBService], _ uuid: String) -> CBService? {
    let matchString = uuid.uppercased()
    for service in list {
        if (service.uuid.uuidString == matchString) {
            return service
        }
    }
    return nil;
}


public func getCharacteristicFromList(_ list: [CBCharacteristic], _ uuid: String) -> CBCharacteristic? {
    let matchString = uuid.uppercased()
    for characteristic in list {
        if (characteristic.uuid.uuidString == matchString) {
            return characteristic
        }
    }
    return nil;
}

public func fletcher32(_ data: [UInt8]) -> UInt32 {
    var data16 = [UInt16]()
    
    var index = 1
    while index < data.count {
        data16.append(Conversion.uint8_array_to_uint16([data[index-1],data[index]]))
        index += 2
    }
    if (data.count % 2 != 0) {
        data16.append(Conversion.uint8_array_to_uint16([data[data.count-1],0]))
    }
    
    return fletcher32(data16)
}


public func fletcher32( _ data: [UInt16]) -> UInt32 {
    var c0 : UInt32 = 0
    var c1 : UInt32 = 0
    let iterations : Int = data.count / 360
    var length : Int = data.count
    var index = 0
    for _ in 0...iterations {
        let blockLength = min(360, length)
        for _ in 0...blockLength - 1 {
            c0 = c0 + UInt32(data[index]);
            c1 = c1 + c0;
            index += 1
        }
        c0 = c0 % 65535
        c1 = c1 % 65535
        length -= 360
    }
    
    return (c1 << 16 | c0)
}



public func promiseBatchPerformer(arr: [voidPromiseCallback], index: Int) -> Promise<Void> {
    return Promise<Void> { seal in
        if (index < arr.count) {
            arr[index]()
                .then{  () in return promiseBatchPerformer(arr: arr, index: index+1)}
                .done{  () in seal.fulfill(()) }
                .catch{ err in seal.reject(err) }
        }
        else {
            seal.fulfill(())
        }
    }
}
