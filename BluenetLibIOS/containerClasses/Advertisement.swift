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


public class Advertisement {
    public var uuid : String
    public var name : String
    public var rssi : NSNumber
    public var serviceData = [String: [UInt8]]()
    public var serviceDataAvailable : Bool
    
    init(uuid: String, name: String?, rssi: NSNumber, serviceData: AnyObject?) {
        if (name != nil) {
            self.name = name!
        }
        else {
            self.name = ""
        }
        self.uuid = uuid
        self.rssi = rssi
        self.serviceDataAvailable = false
        
        if let castData = serviceData as? [CBUUID: NSData] {
            for (serviceCUUID, data) in castData {
                // convert data to uint8 array
                let uint8Arr = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(data.bytes), count: data.length))
                self.serviceData[serviceCUUID.UUIDString] = uint8Arr
                self.serviceDataAvailable = true
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
                if (id == "C001") {
                    let crownstoneScanResponse = ScanResponcePacket(data)
                    serviceData[id] = crownstoneScanResponse.getJSON()
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
        dataDict["id"] = self.uuid
        dataDict["name"] = self.name
        dataDict["rssi"] = self.rssi
        
        var dataJSON = JSON(dataDict)
        dataJSON["serviceData"] = self.getServiceDataJSON()
        return dataJSON
    }
    
    public func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
}
