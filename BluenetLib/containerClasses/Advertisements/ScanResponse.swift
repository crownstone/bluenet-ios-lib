//
//  ServiceData.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 08/01/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth
import SwiftyJSON

public class ScanResponsePacket {
    public var opCode              :   UInt8    = 0
    public var dataType            :   UInt8    = 0
    public var crownstoneId        :   UInt8    = 0
    public var switchState         :   UInt8    = 0
    public var flagsBitmask        :   UInt8    = 0
    public var temperature         :   Int8     = 0
    public var powerFactor         :   Double   = 1
    public var powerUsageReal      :   Double   = 0
    public var powerUsageApparent  :   Double   = 0
    public var accumulatedEnergy   :   Int32    = 0
    public var setupMode           :   Bool     = false
    public var stateOfExternalCrownstone : Bool = false
    public var data                :   [UInt8]!
    public var encryptedData       :   [UInt8]!
    public var encryptedDataStartIndex : Int = 1
    
    public var dimmingAvailable    :   Bool     = false
    public var dimmingAllowed      :   Bool     = false
    public var hasError            :   Bool     = false
    public var switchLocked        :   Bool     = false
    
    public var partialTimestamp    :   UInt16   = 0
    public var timestamp           :   Double   = -1
    
    public var validation          :   UInt8  = 0x00 // Will be 0xFA if it is set.
    
    // TYPE ERROR (opCode 3, type 1)
    public var errorTimestamp      :   UInt32   = 0
    public var errorsBitmask       :   UInt32   = 0
    public var errorMode           :   Bool     = false
    public var timeSet             :   Bool     = false
    public var switchCraftEnabled  :   Bool     = false
    
    public var uniqueIdentifier    :   NSNumber = 0
    
    public var deviceType          :   DeviceType = .undefined
    public var rssiOfExternalCrownstone : Int8  = 0
    
    var validData = false
    public var dataReadyForUse = false // decryption is successful
    
    init(_ data: [UInt8], liteParse : Bool = false) {
        self.data = data
        self.parse(liteParse: liteParse)
    }
    
    func parse(liteParse : Bool) {
        validData = true
        if (data.count == 18) {
            self.opCode = data[0]
            self.encryptedData = Array(data[2...])
            self.encryptedDataStartIndex = 2
            switch (self.opCode) {
                case 5:
                    parseOpcode5(serviceData: self, data: data, liteParse: liteParse)
                case 6:
                    parseOpcode6(serviceData: self, data: data, liteParse: liteParse)
                default:
                    parseOpcode5(serviceData: self, data: data, liteParse: liteParse)
            }
        }
        else if (data.count == 17) {
            self.opCode = data[0]
            self.encryptedData = Array(data[1...])
            self.encryptedDataStartIndex = 1
            switch (self.opCode) {
            case 1:
                parseOpcode1(serviceData: self, data: data)
            case 2:
                parseOpcode2(serviceData: self, data: data)
            case 3:
                parseOpcode3(serviceData: self, data: data, liteParse: liteParse)
            case 4:
                parseOpcode4(serviceData: self, data: data, liteParse: liteParse)
            default:
                parseOpcode3(serviceData: self, data: data, liteParse: liteParse)
            }
        }
        else {
            validData = false
        }
    }
    
    
    
    public func hasCrownstoneDataFormat() -> Bool {
        return validData
    }
    
    public func getUniqueElement() -> String {
        return Conversion.uint8_array_to_hex_string(
                Conversion.uint32_to_uint8_array(self.uniqueIdentifier.uint32Value)
        )
    }
    
    public func getDictionary() -> NSDictionary {
        let errorsDictionary = CrownstoneErrors(bitMask: self.errorsBitmask).getDictionary()
        let returnDict : [String: Any] = [
            "opCode"               : NSNumber(value: self.opCode),
            "dataType"             : NSNumber(value: self.dataType),
            "stateOfExternalCrownstone" : self.stateOfExternalCrownstone,
            "hasError"             : self.hasError,
            "setupMode"            : self.isSetupPackage(),
            
            "crownstoneId"         : NSNumber(value: self.crownstoneId),
            "switchState"          : NSNumber(value: self.switchState),
            "flagsBitmask"         : NSNumber(value: self.flagsBitmask),
            "temperature"          : NSNumber(value: self.temperature),
            "powerFactor"          : NSNumber(value: self.powerFactor),
            "powerUsageReal"       : NSNumber(value: self.powerUsageReal),
            "powerUsageApparent"   : NSNumber(value: self.powerUsageApparent),
            "accumulatedEnergy"    : NSNumber(value: self.accumulatedEnergy),
            "timestamp"            : NSNumber(value: self.timestamp),
            
            "dimmingAvailable"     : self.dimmingAvailable,
            "dimmingAllowed"       : self.dimmingAllowed,
            "switchLocked"         : self.switchLocked,
            "switchCraftEnabled"   : self.switchCraftEnabled,
            
            "errorMode"            : self.errorMode,
            "errors"               : errorsDictionary,
            
            "uniqueElement"        : self.uniqueIdentifier,
            "timeSet"              : self.timeSet,
            "deviceType"           : String(describing: self.deviceType),
            "rssiOfExternalCrownstone" : self.rssiOfExternalCrownstone
        ]
        
        return returnDict as NSDictionary
    }
    
    public func getJSON() -> JSON {
        return JSON(self.getDictionary())
    }
    
    public func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
    public func isSetupPackage() -> Bool {
        if (validData == false) {
            return false
        }
        
        switch (self.opCode) {
        case 1,2:
            if (crownstoneId == 0 && switchState == 0 && powerUsageReal == 0 && accumulatedEnergy == 0 && setupMode == true) {
                return true
            }
            else {
                return false
            }
        case 3, 5:
            return false
        case 4, 6:
            return true
        default:
            return false
        }
    }
    
    public func decrypt(_ key: [UInt8]) {
        if (validData == true && self.encryptedData.count == 16) {
            do {
                let result = try EncryptionHandler.decryptAdvertisement(self.encryptedData, key: key)
                
                for i in [Int](0...result.count-1) {
                    self.data[i+self.encryptedDataStartIndex] = result[i]
                }
                
                // parse the data again based on the decrypted result
                self.parse(liteParse: false)
                self.dataReadyForUse = true
            }
            catch let err {
                self.dataReadyForUse = false
                LOG.error("Could not decrypt advertisement \(err)")
            }
        }
        else {
            
        }
    }
}
