//
//  Advertisement.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 17/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth
import SwiftyJSON

/**
 * Wrapper for all relevant data of the object
 *
 */
public class Advertisement {
    public var uuid : String
    public var name : String
    public var rssi : NSNumber
    public var isCrownstone : Bool = false
    public var serviceData = [String: [UInt8]]()
    public var serviceDataAvailable : Bool
    public var serviceUUID : String?
    public var scanResponse : ScanResponcePacket?
    
    init(uuid: String, name: String?, rssi: NSNumber, serviceData: AnyObject?, serviceUUID: AnyObject?) {
        if (name != nil) {
            self.name = name!
        }
        else {
            self.name = ""
        }
        self.uuid = uuid
        self.rssi = rssi
        self.serviceDataAvailable = false

        if let castData = serviceUUID as? [CBUUID] {
            self.serviceUUID = castData[0].UUIDString // assuming only one service data uuid
        }
        
        if let castData = serviceData as? [CBUUID: NSData] {
            for (serviceCUUID, data) in castData {
                // convert data to uint8 array
                let uint8Arr = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(data.bytes), count: data.length))
                self.serviceData[serviceCUUID.UUIDString] = uint8Arr
                self.serviceDataAvailable = true
            }
        }
        
        for (id, data) in self.serviceData {
            if (id == "C001") {
                self.scanResponse = ScanResponcePacket(data)
                self.isCrownstone = true
            }
        }

    }
    
    func getNumberArray(data: [UInt8]) -> [NSNumber] {
        var numberArray = [NSNumber]()
        for uint8 in data {
            numberArray.append(NSNumber(unsignedChar: uint8))
        }
        return numberArray
    }
    
    func getServiceDataJSON() -> JSON {
        if (self.serviceDataAvailable) {
            var serviceData = [String: JSON]()
            for (id, data) in self.serviceData {
                if (id == "C001" && self.scanResponse != nil) {
                    serviceData[id] = self.scanResponse!.getJSON()
                }
                else {
                    serviceData[id] = JSON(self.getNumberArray(data))
                }
            }
            return JSON(serviceData);
        }
        else {
            return JSON([])
        }
    }
    
    public func getJSON() -> JSON {
        var dataDict = [String : AnyObject]()
        dataDict["uuid"] = self.uuid
        dataDict["name"] = self.name
        dataDict["rssi"] = self.rssi
        dataDict["setupPackage"] = self.isSetupPackage()
        dataDict["isCrownstone"] = self.isCrownstone
        
        if (self.serviceUUID != nil) {
            dataDict["serviceUUID"] = self.serviceUUID
        }
      
        var dataJSON = JSON(dataDict)
        dataJSON["serviceData"] = self.getServiceDataJSON()
        return dataJSON
    }
    
    public func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
    public func isSetupPackage() -> Bool {
        if (serviceDataAvailable && self.scanResponse != nil) {
            return self.scanResponse!.isSetupPackage();
        }
        
        return false
    }
    
    public func decrypt(key: [UInt8]) {
        if (serviceDataAvailable && self.scanResponse != nil) {
            self.scanResponse!.decrypt(key)
        }
    }
    
    
    
}
