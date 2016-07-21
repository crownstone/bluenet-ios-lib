//
//  packets.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 09/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import SwiftyJSON
/*
 *
 *
 *  These are valid for SDK 0.4.1
 *
 *
 */

class BLEPacket {
    var type : UInt8 = 0
    var length : [UInt8] = [0,0]
    var payload = [UInt8]()
    
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
   
    init(type: ControlType, payload:   String) { super.init(type: type.rawValue, payload: payload);   }
    init(type: ControlType, payload8:  UInt8)  { super.init(type: type.rawValue, payload: payload8);  }
    init(type: ControlType, payload16: UInt16) { super.init(type: type.rawValue, payload: payload16); }
    init(type: ControlType, payload32: UInt32) { super.init(type: type.rawValue, payload: payload32); }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(0)
        arr += self.length
        arr += self.payload
        return arr
    }
}

class DfuPacket : ControlPacket {
    init() {super.init(type: ControlType.GOTO_DFU, payload32: 0xdeadbeef)}
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

    init(type: ConfigurationType, payload:   String) { super.init(type: type.rawValue, payload: payload);   }
    init(type: ConfigurationType, payload8:  UInt8)  { super.init(type: type.rawValue, payload: payload8);  }
    init(type: ConfigurationType, payload16: UInt16) { super.init(type: type.rawValue, payload: payload16); }
    init(type: ConfigurationType, payload32: UInt32) { super.init(type: type.rawValue, payload: payload32); }
    
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

    init(type: StateType, payload:   String) { super.init(type: type.rawValue, payload: payload);   }
    init(type: StateType, payload8:  UInt8)  { super.init(type: type.rawValue, payload: payload8);  }
    init(type: StateType, payload16: UInt16) { super.init(type: type.rawValue, payload: payload16); }
    init(type: StateType, payload32: UInt32) { super.init(type: type.rawValue, payload: payload32); }
    
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
    var crownstoneId        : UInt16
    var crownstoneStateId   : UInt16
    var switchState         : UInt8
    var eventBitmask        : UInt8
    var reserved            : UInt16
    var powerUsage          : Int32
    var accumulatedEnergy   : Int32
    
    init(_ data: [UInt8]) {
        self.crownstoneId      = Conversion.uint8_array_to_uint16([data[0], data[1]])
        self.crownstoneStateId = Conversion.uint8_array_to_uint16([data[2], data[3]])
        self.switchState       = data[4]
        self.eventBitmask      = data[5]
        self.reserved          = Conversion.uint8_array_to_uint16([data[6], data[7]])
        self.powerUsage        = Conversion.uint32_to_int32(
            Conversion.uint8_array_to_uint32([
                data[8],
                data[9],
                data[10],
                data[11]
            ])
        )
        self.accumulatedEnergy = Conversion.uint32_to_int32(
            Conversion.uint8_array_to_uint32([
                data[12],
                data[13],
                data[14],
                data[15]
            ])
        )
    }
    
    public func getJSON() -> JSON {
        var returnDict = [String: NSNumber]()
        returnDict["crownstoneId"] = NSNumber(unsignedShort: self.crownstoneId)
        returnDict["crownstoneStateId"] = NSNumber(unsignedShort: self.crownstoneStateId)
        returnDict["switchState"] = NSNumber(unsignedChar: self.switchState)
        returnDict["eventBitmask"] = NSNumber(unsignedChar: self.eventBitmask)
        returnDict["reserved"] = NSNumber(unsignedShort: self.reserved)
        returnDict["powerUsage"] = NSNumber(int: self.powerUsage)
        returnDict["accumulatedEnergy"] = NSNumber(int: self.accumulatedEnergy)
        
        return JSON(returnDict)
    }
    
    public func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
}








