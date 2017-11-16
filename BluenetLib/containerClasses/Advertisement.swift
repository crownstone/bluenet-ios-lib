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
    open var isCrownstonePlug    : Bool = false
    open var isCrownstoneBuiltin : Bool = false
    open var isGuidestone        : Bool = false
    open var isInDFUMode         : Bool = false
    
    open var serviceData = [String: [UInt8]]()
    open var serviceDataAvailable : Bool
    open var serviceUUID : String?
    open var scanResponse : ScanResponcePacket?
    
    init(handle: String, name: String?, rssi: NSNumber, serviceData: Any, serviceUUID: Any, referenceId: String) {
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
            }
        }
        
        for (id, data) in self.serviceData {
            if (id == CrownstonePlugAdvertisementServiceUUID ||
                id == CrownstoneBuiltinAdvertisementServiceUUID ||
                id == GuidestoneAdvertisementServiceUUID) {
                self.scanResponse        = ScanResponcePacket(data)
                self.isCrownstoneFamily  = self.scanResponse!.hasCrownstoneDataFormat()
                self.isCrownstonePlug    = (id == CrownstonePlugAdvertisementServiceUUID)
                self.isCrownstoneBuiltin = (id == CrownstoneBuiltinAdvertisementServiceUUID)
                self.isGuidestone        = (id == GuidestoneAdvertisementServiceUUID)
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
    
    open func getServiceDataRandomString() -> String {
        if ((scanResponse) != nil) {
            return scanResponse!.getRandomString()
        }
        return ""
    }
    
    open func getJSON() -> JSON {
        var dataDict = [String : Any]()
        dataDict["handle"] = self.handle
        dataDict["name"] = self.name
        dataDict["rssi"] = self.rssi
        dataDict["isCrownstoneFamily"]  = self.isCrownstoneFamily
        dataDict["isCrownstonePlug"]    = self.isCrownstonePlug
        dataDict["isCrownstoneBuiltin"] = self.isCrownstoneBuiltin
        dataDict["isGuidestone"]        = self.isGuidestone
        dataDict["isInDFUMode"]         = self.isInDFUMode
        dataDict["referenceId"]         = self.referenceId
        
        if (self.serviceUUID != nil) {
            dataDict["serviceUUID"] = self.serviceUUID
        }
      
        var dataJSON = JSON(dataDict)
        if (self.serviceDataAvailable) {
            if (self.isCrownstoneFamily) {
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
            "name"   : self.name,
            "rssi"   : self.rssi,
            "isCrownstoneFamily"   : self.isCrownstoneFamily,
            "isCrownstonePlug"     : self.isCrownstonePlug,
            "isCrownstoneBuiltin"  : self.isCrownstoneBuiltin,
            "isGuidestone"         : self.isGuidestone,
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
}




open class ScanResponcePacket {
    open var protocolVersion     : UInt8  = 0
    open var crownstoneId        : UInt16 = 0
    open var switchState         : UInt8  = 0
    open var eventBitmask        : UInt8  = 0
    open var hasError            : Bool   = false
    open var temperature         : Int8   = 0
    open var powerFactor         : Double = 0
    open var powerUsageReal      : Double = 0
	open var powerUsageAppearent : Double = 0
	open var powerUsage          : Double = 0
    open var accumulatedEnergy   : Int32  = 0
    open var random              : String = ""
    open var newDataAvailable    : Bool   = false
    open var setupFlag           : Bool   = false
    open var stateOfExternalCrownstone : Bool = false
    open var data                : [UInt8]!
    
    var validData = false
    
    init(_ data: [UInt8]) {
        self.data = data
        self.parse()
    }
    
    open func getRandomString() -> String {
        return self.random
    }
    
    func parse() {
        if (data.count == 17) {
            self.protocolVersion = data[0]
			switch (self.protocolVersion) {
				case 1: 
					self._parseProtocol_1(); break
				case 2: 
					self._parseProtocol_2(); break
				default:
					self._parseProtocol_1();
			}
            validData = true
        }
        else {
            validData = false
        }
    }
	
	func _parseProtocol_1() {
		self.crownstoneId      = Conversion.uint8_array_to_uint16([data[1], data[2]])
		self.switchState       = data[3]
		self.eventBitmask      = data[4]
		self.temperature       = Conversion.uint8_to_int8(data[5])
		let powerUsageMw       = Conversion.uint32_to_int32(
			Conversion.uint8_array_to_uint32([
				data[6],
				data[7],
				data[8],
				data[9]
			])
		)
        
        self.powerUsage = NSNumber(value: powerUsageMw).doubleValue * 0.001
		self.powerUsageAppearent = self.powerUsage
		
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
		hasError = bitmaskArray[2]
		setupFlag = bitmaskArray[7]
	}
	
	func _parseProtocol_2() {
		self.crownstoneId      = Conversion.uint8_array_to_uint16([data[1], data[2]])
		self.switchState       = data[3]
		self.eventBitmask      = data[4]
		self.temperature       = Conversion.uint8_to_int8(data[5])
		
		let powerFactor = Conversion.uint16_to_int16(
			Conversion.uint8_array_to_uint16([
				data[6],
				data[7]
			])
		)
		let appearentPower = Conversion.uint16_to_int16(
			Conversion.uint8_array_to_uint16([
				data[8],
				data[9]
			])
		)
    
        self.powerFactor         = NSNumber(value: powerFactor as Int16).doubleValue / 1024
		self.powerUsageAppearent = NSNumber(value: appearentPower as Int16).doubleValue / 16
		self.powerUsageReal      = self.powerFactor * self.powerUsageAppearent
        self.powerUsage          = self.powerUsageAppearent

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
		hasError = bitmaskArray[2]
		setupFlag = bitmaskArray[7]		
	}
    
    open func hasCrownstoneDataFormat() -> Bool {
        return validData
    }
    
    open func getJSON() -> JSON {
        var returnDict = [String: NSNumber]()
        returnDict["protocolVersion"] = NSNumber(value: self.protocolVersion)
        returnDict["crownstoneId"] = NSNumber(value: self.crownstoneId)
        returnDict["switchState"] = NSNumber(value: self.switchState)
        returnDict["eventBitmask"] = NSNumber(value: self.eventBitmask)
        returnDict["temperature"] = NSNumber(value: self.temperature)
        returnDict["powerUsage"] = NSNumber(value: self.powerUsage)
        returnDict["powerFactor"] = NSNumber(value: self.powerFactor)
        returnDict["powerUsageReal"] = NSNumber(value: self.powerUsageReal)
        returnDict["powerUsageAppearent"] = NSNumber(value: self.powerUsageAppearent)
        returnDict["accumulatedEnergy"] = NSNumber(value: self.accumulatedEnergy)
        
        // bitmask flags:
        returnDict["newDataAvailable"] = NSNumber(value: self.newDataAvailable)
        returnDict["stateOfExternalCrownstone"] = NSNumber(value: self.stateOfExternalCrownstone)
        returnDict["hasError"] = NSNumber(value: self.hasError)
        returnDict["setupMode"] = NSNumber(value: self.isSetupPackage())
        
        // random flag:
        var dataJSON = JSON(returnDict)
        dataJSON["random"] = JSON(self.random)
        
        return dataJSON
    }
    
    open func getDictionary() -> NSDictionary {
        let returnDict : [String: Any] = [
            "protocolVersion" : NSNumber(value: self.protocolVersion),
            "crownstoneId" : NSNumber(value: self.crownstoneId),
            "switchState" : NSNumber(value: self.switchState),
            "eventBitmask" : NSNumber(value: self.eventBitmask),
            "temperature" : NSNumber(value: self.temperature),
            "powerUsage" : NSNumber(value: self.powerUsage),
            "powerFactor" : NSNumber(value: self.powerFactor),
            "powerUsageReal" : NSNumber(value: self.powerUsageReal),
            "powerUsageAppearent" : NSNumber(value: self.powerUsageAppearent),
            "accumulatedEnergy" : NSNumber(value: self.accumulatedEnergy),
            "newDataAvailable" : self.newDataAvailable,
            "stateOfExternalCrownstone" : self.stateOfExternalCrownstone,
            "hasError": self.hasError,
            "setupMode" : self.isSetupPackage(),
            "random" : self.random
        ]
        
        return returnDict as NSDictionary
    }
    
    open func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
    open func isSetupPackage() -> Bool {
        if (validData == false) {
            return false
        }
        
        if (crownstoneId == 0 && switchState == 0 && powerUsage == 0 && accumulatedEnergy == 0 && setupFlag == true) {
            return true
        }
        
        return false
    }
    
    open func decrypt(_ key: [UInt8]) {
        if (validData == true) {
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
            catch let err {
                LOG.error("Could not decrypt advertisement \(err)")
            }
        }
        else {
            
        }
    }
}
