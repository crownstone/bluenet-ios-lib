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
open class Advertisement {
    open var handle : String
    open var name : String
    open var rssi : NSNumber
    open var referenceId : String // id of the entity that provides the keys
    
    open var isCrownstoneFamily  : Bool = false
    open var isInDFUMode         : Bool = false
    
    open var serviceData = [String: [UInt8]]()
    open var serviceDataAvailable : Bool
    open var serviceUUID : String?
    open var scanResponse : ScanResponsePacket?
    
    init(handle: String, name: String?, rssi: NSNumber, serviceData: Any, serviceUUID: Any, referenceId: String, liteParse: Bool = false) {
        self.referenceId = referenceId
        
        if (name != nil) {
            self.name = name!
        }
        else {
            self.name = ""
        }
        self.handle = handle
        self.rssi = rssi
        self.serviceDataAvailable = false

        if let castData = serviceUUID as? [CBUUID] {
            self.serviceUUID = castData[0].uuidString // assuming only one service data uuid
            self.isInDFUMode = self.serviceUUID == DFUServiceUUID
        }
        
        if let castData = serviceData as? [CBUUID: Data] {
            for (serviceCUUID, data) in castData {
                // convert data to uint8 array
                let uint8Arr = Array(UnsafeBufferPointer(start: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), count: data.count))
                self.serviceData[serviceCUUID.uuidString] = uint8Arr
                self.serviceUUID = serviceCUUID.uuidString
                self.serviceDataAvailable = true
                self.isInDFUMode = false
            }
        }
        
        for (id, data) in self.serviceData {
            if (id == CrownstonePlugAdvertisementServiceUUID ||
                id == CrownstoneBuiltinAdvertisementServiceUUID ||
                id == GuidestoneAdvertisementServiceUUID) {
                self.scanResponse        =  ScanResponsePacket(data, liteParse : liteParse)
                self.isCrownstoneFamily  =  self.scanResponse!.hasCrownstoneDataFormat()
                break
            }
        }
    }
    
    func getNumberArray(_ data: [UInt8]) -> [NSNumber] {
        var numberArray = [NSNumber]()
        for uint8 in data {
            numberArray.append(NSNumber(value: uint8))
        }
        return numberArray
    }
    
    func getServiceDataJSON() -> JSON {
        if (self.serviceDataAvailable) {
            for (id, data) in self.serviceData {
                if ((
                    id == CrownstonePlugAdvertisementServiceUUID ||
                    id == CrownstoneBuiltinAdvertisementServiceUUID ||
                    id == GuidestoneAdvertisementServiceUUID) &&
                    self.scanResponse != nil) {
                    return self.scanResponse!.getJSON()
                }
                else {
                    return JSON(self.getNumberArray(data))
                }
            }
        }

        return JSON([])
    }

    open func getUniqueElement() -> String {
        if ((scanResponse) != nil) {
            return scanResponse!.getUniqueElement()
        }
        return ""
    }
    
    open func getJSON() -> JSON {
        return JSON(self.getDictionary())
    }
    
    open func getDictionary() -> NSDictionary {
        var returnDict : [String: Any] = [
            "handle" : self.handle,
            "name"   : self.name,
            "rssi"   : self.rssi,
            "isCrownstoneFamily"   : self.isCrownstoneFamily,
            "isInDFUMode"          : self.isInDFUMode,
            "referenceId"          : self.referenceId
        ]
        
        if (self.serviceUUID != nil) {
            returnDict["serviceUUID"] = self.serviceUUID!
        }
        
        if (self.serviceDataAvailable) {
            if (self.isCrownstoneFamily) {
                returnDict["serviceData"] = self.scanResponse!.getDictionary()
            }
            else {
                returnDict["serviceData"] = self.getNumberArray(self.serviceData[self.serviceUUID!]!)
            }
        }
        
        return returnDict as NSDictionary
    }

    
    open func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
    
    open func isSetupPackage() -> Bool {
        if (serviceDataAvailable && self.scanResponse != nil) {
            return self.scanResponse!.isSetupPackage()
        }
        return false
    }
    
    open func isDFUPackage() -> Bool {
        return self.isInDFUMode
    }
    
    open func hasScanResponse() -> Bool {
        return (serviceDataAvailable && self.scanResponse != nil)
    }
    
    open func decrypt( _ key: [UInt8] ) {
        if (serviceDataAvailable && self.scanResponse != nil) {
            self.scanResponse!.decrypt(key)
        }
    }
    
    open func fullParse() {
        if (serviceDataAvailable && self.scanResponse != nil) {
            self.scanResponse!.parse(liteParse: false)
        }
    }
}




