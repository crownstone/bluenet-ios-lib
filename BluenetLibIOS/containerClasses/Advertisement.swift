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

let CROWNSTONE_SERVICEDATA_UUID = "C001"

/**
 * Wrapper for all relevant data of the object
 *
 */
open class Advertisement {
    open var handle : String
    open var name : String
    open var rssi : NSNumber
    open var isCrownstone : Bool = false
    open var serviceData = [String: [UInt8]]()
    open var serviceDataAvailable : Bool
    open var serviceUUID : String?
    open var scanResponse : ScanResponcePacket?
    
    init(handle: String, name: String?, rssi: NSNumber, serviceData: Any, serviceUUID: Any) {
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
        }
        
        if let castData = serviceData as? [CBUUID: Data] {
            for (serviceCUUID, data) in castData {
                // convert data to uint8 array
                let uint8Arr = Array(UnsafeBufferPointer(start: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), count: data.count))
                self.serviceData[serviceCUUID.uuidString] = uint8Arr
                self.serviceUUID = serviceCUUID.uuidString
                self.serviceDataAvailable = true
            }
        }
        
        for (id, data) in self.serviceData {
            if (id == CROWNSTONE_SERVICEDATA_UUID) {
                self.scanResponse = ScanResponcePacket(data)
                self.isCrownstone = true
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
                if (id == CROWNSTONE_SERVICEDATA_UUID && self.scanResponse != nil) {
                    return self.scanResponse!.getJSON()
                }
                else {
                    return JSON(self.getNumberArray(data))
                }
            }
        }

        return JSON([])
    }
    
    open func getJSON() -> JSON {
        var dataDict = [String : Any]()
        dataDict["handle"] = self.handle
        dataDict["name"] = self.name
        dataDict["rssi"] = self.rssi
        dataDict["isCrownstone"] = self.isCrownstone
        
        if (self.serviceUUID != nil) {
            dataDict["serviceUUID"] = self.serviceUUID
        }
      
        var dataJSON = JSON(dataDict)
        if (self.serviceDataAvailable) {
            if (self.isCrownstone) {
                dataJSON["serviceData"] = self.scanResponse!.getJSON()
            }
            else {
                dataJSON["serviceData"] = JSON(self.getNumberArray(self.serviceData[self.serviceUUID!]!))
            }
        }
        
        return dataJSON
    }
    
    open func getDictionary() -> NSDictionary {
        var returnDict : [String: Any] = [
            "handle" : self.handle,
            "name" : self.name,
            "rssi" : self.rssi,
            "isCrownstone" : self.isCrownstone
        ]
        
        if (self.serviceUUID != nil) {
            returnDict["serviceUUID"] = self.serviceUUID!
        }
        
        if (self.serviceDataAvailable) {
            if (self.isCrownstone) {
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
        if (serviceDataAvailable && self.scanResponse != nil) {
            return self.scanResponse!.isDFUPackage()
        }
        return false
    }
    
    open func hasScanResponse() -> Bool {
        return (serviceDataAvailable && self.scanResponse != nil)
    }
    
    open func decrypt(_ key: [UInt8]) {
        if (serviceDataAvailable && self.scanResponse != nil) {
            self.scanResponse!.decrypt(key)
        }
    }
}




open class ScanResponcePacket {
    var firmwareVersion     : UInt8!
    var crownstoneId        : UInt16!
    var switchState         : UInt8!
    var eventBitmask        : UInt8!
    var temperature         : Int8!
    var powerUsage          : Int32!
    var accumulatedEnergy   : Int32!
    var random              : String!
    var newDataAvailable    : Bool!
    var setupFlag           : Bool!
    var dfuMode             : Bool!
    var stateOfExternalCrownstone : Bool!
    var data                : [UInt8]!
    
    init(_ data: [UInt8]) {
        self.data = data
        self.parse()
    }
    
    func parse() {
        self.firmwareVersion   = data[0]
        self.crownstoneId      = Conversion.uint8_array_to_uint16([data[1], data[2]])
        self.switchState       = data[3]
        self.eventBitmask      = data[4]
        self.temperature       = Conversion.uint8_to_int8(data[5])
        self.powerUsage        = Conversion.uint32_to_int32(
            Conversion.uint8_array_to_uint32([
                data[6],
                data[7],
                data[8],
                data[9]
            ])
        )
        self.accumulatedEnergy = Conversion.uint32_to_int32(
            Conversion.uint8_array_to_uint32([
                data[10],
                data[11],
                data[12],
                data[13]
            ])
        )
        self.random = Conversion.uint8_array_to_hex_string([data[14],data[15],data[16]])
        
        // bitmask states
        let bitmaskArray = Conversion.uint8_to_bit_array(self.eventBitmask)
        newDataAvailable = bitmaskArray[0]
        stateOfExternalCrownstone = bitmaskArray[1]
        setupFlag = bitmaskArray[7]
        dfuMode = false;
    }
    
    open func getJSON() -> JSON {
        var returnDict = [String: NSNumber]()
        returnDict["firmwareVersion"] = NSNumber(value: self.firmwareVersion)
        returnDict["crownstoneId"] = NSNumber(value: self.crownstoneId)
        returnDict["switchState"] = NSNumber(value: self.switchState)
        returnDict["eventBitmask"] = NSNumber(value: self.eventBitmask)
        returnDict["temperature"] = NSNumber(value: self.temperature)
        returnDict["powerUsage"] = NSNumber(value: self.powerUsage)
        returnDict["accumulatedEnergy"] = NSNumber(value: self.accumulatedEnergy)
        
        // bitmask flags:
        returnDict["newDataAvailable"] = NSNumber(value: self.newDataAvailable)
        returnDict["stateOfExternalCrownstone"] = NSNumber(value: self.stateOfExternalCrownstone)
        returnDict["setupMode"] = NSNumber(value: self.isSetupPackage())
        returnDict["dfuMode"] = NSNumber(value: self.isDFUPackage())
        
        // random flag:
        var dataJSON = JSON(returnDict)
        dataJSON["random"] = JSON(self.random)
        
        return dataJSON
    }
    
    open func getDictionary() -> NSDictionary {
        let returnDict : [String: Any] = [
            "firmwareVersion" : NSNumber(value: self.firmwareVersion),
            "crownstoneId" : NSNumber(value: self.crownstoneId),
            "switchState" : NSNumber(value: self.switchState),
            "eventBitmask" : NSNumber(value: self.eventBitmask),
            "temperature" : NSNumber(value: self.temperature),
            "powerUsage" : NSNumber(value: self.powerUsage),
            "accumulatedEnergy" : NSNumber(value: self.accumulatedEnergy),
            "newDataAvailable" : self.newDataAvailable,
            "stateOfExternalCrownstone" : self.stateOfExternalCrownstone,
            "setupMode" : self.isSetupPackage(),
            "dfuMode" : self.isDFUPackage()
        ]
        
        return returnDict as NSDictionary
    }
    
    open func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
    open func isSetupPackage() -> Bool {
        if (crownstoneId == 0 && switchState == 0 && powerUsage == 0 && accumulatedEnergy == 0 && setupFlag == true) {
            return true
        }
        return false
    }
    
    open func isDFUPackage() -> Bool {
        // TODO: define.
        return false
    }
    
    open func decrypt(_ key: [UInt8]) {
        var encryptedData = [UInt8](repeating: 0, count: 16)
        // copy the data we want to encrypt into a buffer
        for i in [Int](1...data.count-1) {
            encryptedData[i-1] = data[i]
        }
        
        do {
            let result = try EncryptionHandler.decryptAdvertisement(encryptedData, key: key)
            
            for i in [Int](0...result.count-1) {
                self.data[i+1] = result[i]
            }
            // parse the data again based on the decrypted result
            self.parse()
        }
        catch {}
    }
}
