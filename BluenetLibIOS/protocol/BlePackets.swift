//
//  packets.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 09/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import SwiftyJSON
import CryptoSwift
/*
 *
 *
 *  These are valid for SDK 0.6.0
 *
 *
 */

class BLEPacket {
    var type : UInt8 = 0
    var length : [UInt8] = [0,0]
    var payload = [UInt8]()
    
    init(type: UInt8) {
        self.type = type
        self.payload = []
        self.length = [0,0]
    }
    
    init(type: UInt8, payload: String) {
        self.type = type
        self.payload = Conversion.string_to_uint8_array(payload)
        self.length = Conversion.uint16_to_uint8_array(__uint16_t(self.payload.count))
    }
    
    init(type: UInt8, payload: UInt8) {
        self.type = type
        self.payload = [payload]
        self.length = Conversion.uint16_to_uint8_array(__uint16_t(self.payload.count))
    }
    
    init(type: UInt8, payload: UInt16) {
        self.type = type
        self.payload = Conversion.uint16_to_uint8_array(payload)
        self.length = Conversion.uint16_to_uint8_array(__uint16_t(self.payload.count))
    }
    
    init(type: UInt8, payload: UInt32) {
        self.type = type
        self.payload = Conversion.uint32_to_uint8_array(payload)
        self.length = Conversion.uint16_to_uint8_array(__uint16_t(self.payload.count))
    }
    
    init(type: UInt8, payload: [UInt8]) {
        self.type = type
        self.payload = payload
        self.length = Conversion.uint16_to_uint8_array(__uint16_t(self.payload.count))
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(0)
        arr += self.length
        arr += self.payload
        return arr
    }
    
    func getNSData() -> NSData {
        let bytes = self.getPacket()
        return NSData(bytes: bytes, length: bytes.count)
    }
}

class ControlPacket : BLEPacket {
   
    init(type: ControlType)                    { super.init(type: type.rawValue)  }
    init(type: ControlType, payload:   String) { super.init(type: type.rawValue, payload: payload)   }
    init(type: ControlType, payload8:  UInt8)  { super.init(type: type.rawValue, payload: payload8)  }
    init(type: ControlType, payload16: UInt16) { super.init(type: type.rawValue, payload: payload16) }
    init(type: ControlType, payload32: UInt32) { super.init(type: type.rawValue, payload: payload32) }
    init(type: ControlType, payloadArray: [UInt8]) { super.init(type: type.rawValue, payload: payloadArray) }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(0)
        arr += self.length
        arr += self.payload
        return arr
    }
}

class FactoryResetPacket : ControlPacket {
    init() {super.init(type: ControlType.FACTORY_RESET, payload32: 0xdeadbeef)}
}


class EnableScannerPacket : ControlPacket {
    init(payload8: UInt8) {super.init(type: ControlType.ENABLE_SCANNER, payload8: payload8)}
}

class EnableScannerDelayPacket : ControlPacket {
    init(delayInMs: Int) {super.init(type: ControlType.ENABLE_SCANNER, payload16: UInt16(delayInMs))}
}

class MeshControlPacket {
    
}

class MeshPayloadPacket {
    
}

class ReadConfigPacket : BLEPacket {

    init(type: ConfigurationType)                    { super.init(type: type.rawValue) }
    init(type: ConfigurationType, payload:   String) { super.init(type: type.rawValue, payload: payload)   }
    init(type: ConfigurationType, payload8:  UInt8)  { super.init(type: type.rawValue, payload: payload8)  }
    init(type: ConfigurationType, payload16: UInt16) { super.init(type: type.rawValue, payload: payload16) }
    init(type: ConfigurationType, payload32: UInt32) { super.init(type: type.rawValue, payload: payload32) }
    init(type: ConfigurationType, payloadArray: [UInt8]) { super.init(type: type.rawValue, payload: payloadArray) }
    
    func getOpCode() -> OpCode { return .READ }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(self.getOpCode().rawValue)
        arr += self.length
        arr += self.payload
        return arr
    }
}
class WriteConfigPacket : ReadConfigPacket {
    override func getOpCode() -> OpCode { return .WRITE }
}


class ReadStatePacket : BLEPacket {

    init(type: StateType)                    { super.init(type: type.rawValue) }
    init(type: StateType, payload:   String) { super.init(type: type.rawValue, payload: payload)   }
    init(type: StateType, payload8:  UInt8)  { super.init(type: type.rawValue, payload: payload8)  }
    init(type: StateType, payload16: UInt16) { super.init(type: type.rawValue, payload: payload16) }
    init(type: StateType, payload32: UInt32) { super.init(type: type.rawValue, payload: payload32) }
    init(type: StateType, payloadArray: [UInt8]) { super.init(type: type.rawValue, payload: payloadArray) }
    
    func getOpCode() -> OpCode {
        return .READ
    }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(self.getOpCode().rawValue)
        arr += self.length
        arr += self.payload
        return arr
    }
}

class WriteStatePacket : ReadStatePacket {
    override func getOpCode() -> OpCode { return .WRITE }
}

class NotificationStatePacket : ReadStatePacket {
    override func getOpCode() -> OpCode { return .NOTIFY }
}


public class ScanResponcePacket {
    var firmwareVersion     : UInt8!
    var crownstoneId        : UInt16!
    var switchState         : UInt8!
    var eventBitmask        : UInt8!
    var temperature         : Int8!
    var powerUsage          : Int32!
    var accumulatedEnergy   : Int32!
    var random              : String!
    var newDataAvailable    : Bool!
    var setupMode           : Bool!
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
        setupMode = bitmaskArray[7]
    }
    
    public func getJSON() -> JSON {
        var returnDict = [String: NSNumber]()
        returnDict["firmwareVersion"] = NSNumber(unsignedChar: self.firmwareVersion)
        returnDict["crownstoneId"] = NSNumber(unsignedShort: self.crownstoneId)
        returnDict["switchState"] = NSNumber(unsignedChar: self.switchState)
        returnDict["eventBitmask"] = NSNumber(unsignedChar: self.eventBitmask)
        returnDict["temperature"] = NSNumber(char: self.temperature)
        returnDict["powerUsage"] = NSNumber(int: self.powerUsage)
        returnDict["accumulatedEnergy"] = NSNumber(int: self.accumulatedEnergy)

        // bitmask flags:
        returnDict["newDataAvailable"] = NSNumber(bool: self.newDataAvailable)
        returnDict["stateOfExternalCrownstone"] = NSNumber(bool: self.stateOfExternalCrownstone)
        returnDict["setupMode"] = NSNumber(bool: self.setupMode)
        
        // random flag:
        var dataJSON = JSON(returnDict)
        dataJSON["random"] = JSON(self.random)
        
        return dataJSON
    }
    
    public func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
    public func isSetupPackage() -> Bool {
        if (crownstoneId == 0 && switchState == 0 && powerUsage == 0 && accumulatedEnergy == 0 && setupMode == true) {
            return true
        }
        return false
    }
    
    public func decrypt(key: [UInt8]) {
        var encryptedData = [UInt8](count: 16, repeatedValue:0)
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








