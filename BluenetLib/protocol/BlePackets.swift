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
 *  These are valid for SDK 0.13.0
 *
 *
 */

protocol BLEPacketBaseProtocol {
    func load(_ payload: [UInt8]) -> Self
    func load(_ payload: UInt8)   -> Self
    func load(_ payload: UInt16)  -> Self
    func load(_ payload: UInt32)  -> Self
    func load(_ payload: String)  -> Self
    func load(_ payload: Int8)    -> Self
    func load(_ payload: Float)   -> Self
    
    func getPacket() -> [UInt8]
}

class BLEPacketBase: BLEPacketBaseProtocol {
    var payload = [UInt8]()
    var length : UInt16 = 0
    
    func load(_ payload: [UInt8]) -> Self {
        self.payload = payload
        self.length = UInt16(payload.count)
        return self
    }
    func load(_ payload: UInt8) -> Self {
        self.payload = [payload]
        self.length = 1
        return self
    }
    func load(_ payload: UInt16) -> Self {
        self.payload = Conversion.uint16_to_uint8_array(payload)
        self.length = 2
        return self
    }
    func load(_ payload: UInt32) -> Self {
        self.payload = Conversion.uint32_to_uint8_array(payload)
        self.length = 4
        return self
    }
    func load(_ payload: String) -> Self {
        self.payload = Conversion.string_to_uint8_array(payload)
        self.length = UInt16(self.payload.count)
        return self
    }
    func load(_ payload: Int8) -> Self {
        self.payload = [Conversion.int8_to_uint8(payload)]
        self.length = 1
        return self
    }
    func load(_ payload: Float) -> Self {
        self.payload = Conversion.float_to_uint8_array(payload)
        self.length = 4
        return self
    }
    
    func getPacket() -> [UInt8] {
        return []
    }
}


class BLEPacket : BLEPacketBase {
    var type : UInt8 = 0
    
    init(type: UInt8) {
        self.type = type
    }
    
    init(type: UInt8, payload: String) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt8, payload: Int8) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt8, payload: UInt8) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt8, payload: UInt16) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt8, payload: UInt32) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt8, payload: [UInt8]) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt8, payloadFloat: Float) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(0) // reserved
        arr += Conversion.uint16_to_uint8_array(self.length)
        arr += self.payload
        return arr
    }
    
    
    func getNSData() -> Data {
        let bytes = self.getPacket()
        return Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
    }
}


class BLEPacketV2 : BLEPacketBase {
    var type : UInt16 = 0
    
    init(type: UInt16) {
        self.type = type
    }
    
    init(type: UInt16, payload: String) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt16, payload: Int8) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt16, payload: UInt8) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt16, payload: UInt16) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt16, payload: UInt32) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt16, payload: [UInt8]) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    init(type: UInt16, payload: Float) {
        super.init()
        self.type = type
        _ = self.load(payload)
    }
    
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr += Conversion.uint16_to_uint8_array(self.type)
        arr += Conversion.uint16_to_uint8_array(self.length)
        arr += self.payload
        return arr
    }
    
    func getNSData() -> Data {
        let bytes = self.getPacket()
        return Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
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
        arr.append(0) // reserved
        arr += Conversion.uint16_to_uint8_array(self.length)
        arr += self.payload
        return arr
    }
}

class ControlPacketV2 : BLEPacketV2 {
   
    init(type: ControlTypeV2)                    { super.init(type: type.rawValue)  }
    init(type: ControlTypeV2, payload:   String) { super.init(type: type.rawValue, payload: payload)   }
    init(type: ControlTypeV2, payload8:  UInt8)  { super.init(type: type.rawValue, payload: payload8)  }
    init(type: ControlTypeV2, payload16: UInt16) { super.init(type: type.rawValue, payload: payload16) }
    init(type: ControlTypeV2, payload32: UInt32) { super.init(type: type.rawValue, payload: payload32) }
    init(type: ControlTypeV2, payloadArray: [UInt8]) { super.init(type: type.rawValue, payload: payloadArray) }
    init(type: ControlTypeV2, payloadFloat: Float) { super.init(type: type.rawValue, payload: payloadFloat) }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr += Conversion.uint16_to_uint8_array(self.type)
        arr += Conversion.uint16_to_uint8_array(self.length)
        arr += self.payload
        return arr
    }
}

class ControlStateSetPacket : ControlPacketV2 {
    
    var stateType : UInt16
   
    init(type: StateTypeV2)                        { self.stateType = type.rawValue; super.init(type: ControlTypeV2.setState)  }
    init(type: StateTypeV2, payload:   String)     { self.stateType = type.rawValue; super.init(type: ControlTypeV2.setState, payload: payload)   }
    init(type: StateTypeV2, payload8:  UInt8)      { self.stateType = type.rawValue; super.init(type: ControlTypeV2.setState, payload8: payload8)  }
    init(type: StateTypeV2, payload16: UInt16)     { self.stateType = type.rawValue; super.init(type: ControlTypeV2.setState, payload16: payload16) }
    init(type: StateTypeV2, payload32: UInt32)     { self.stateType = type.rawValue; super.init(type: ControlTypeV2.setState, payload32: payload32) }
    init(type: StateTypeV2, payloadArray: [UInt8]) { self.stateType = type.rawValue; super.init(type: ControlTypeV2.setState, payloadArray: payloadArray) }
    init(type: StateTypeV2, payloadFloat: Float)   { self.stateType = type.rawValue; super.init(type: ControlTypeV2.setState, payloadFloat: payloadFloat) }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr += Conversion.uint16_to_uint8_array(self.type)
        arr += Conversion.uint16_to_uint8_array(self.length + 2) // the + 2 is for the stateType uint16
        arr += Conversion.uint16_to_uint8_array(self.stateType)
        arr += self.payload
        return arr
    }
}


class ControlStateGetPacket : ControlPacketV2 {
    init(type: StateTypeV2) { super.init(type: ControlTypeV2.getState, payload16: type.rawValue)  }
}

class KeepAliveStatePacket : ControlPacket {

    init(action: UInt8, state: UInt8, timeout: UInt16) {
        var data = [UInt8]()
        
        data.append(action)
        data.append(state)
        
        let timeoutArray = Conversion.uint16_to_uint8_array(timeout)
        data.append(timeoutArray[0])
        data.append(timeoutArray[1])
        
        super.init(type: ControlType.keep_ALIVE_STATE, payloadArray: data)
    }
}

class FactoryResetPacket : ControlPacket {
    init() {super.init(type: ControlType.factory_RESET, payload32: 0xdeadbeef)}
}
class FactoryResetPacketV2 : ControlPacketV2 {
    init() {super.init(type: ControlTypeV2.factory_RESET, payload32: 0xdeadbeef)}
}


class EnableScannerPacket : ControlPacket {
    init(payload8: UInt8) {super.init(type: ControlType.enable_SCANNER, payload8: payload8)}
}

class EnableScannerDelayPacket : ControlPacket {
    init(delayInMs: Int) {super.init(type: ControlType.enable_SCANNER, payload16: UInt16(delayInMs))}
}

class ReadConfigPacket : BLEPacket {

    init(type: ConfigurationType)                    { super.init(type: type.rawValue) }
    init(type: ConfigurationType, payload:   String) { super.init(type: type.rawValue, payload: payload)   }
    init(type: ConfigurationType, payload8:  Int8)   { super.init(type: type.rawValue, payload: payload8)  }
    init(type: ConfigurationType, payload8:  UInt8)  { super.init(type: type.rawValue, payload: payload8)  }
    init(type: ConfigurationType, payload16: UInt16) { super.init(type: type.rawValue, payload: payload16) }
    init(type: ConfigurationType, payload32: UInt32) { super.init(type: type.rawValue, payload: payload32) }
    init(type: ConfigurationType, payloadArray: [UInt8]) { super.init(type: type.rawValue, payload: payloadArray) }
    init(type: ConfigurationType, payloadFloat: Float  ) { super.init(type: type.rawValue, payloadFloat: payloadFloat)  }
    
    func getOpCode() -> OpCode { return .read }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(self.getOpCode().rawValue)
        arr += Conversion.uint16_to_uint8_array(self.length)
        arr += self.payload
        return arr
    }
}
class WriteConfigPacket : ReadConfigPacket {
    override func getOpCode() -> OpCode { return .write }
}



class ReadStatePacket : BLEPacket {

    init(type: StateType)                         { super.init(type: type.rawValue) }
    init(type: StateType, payload:       String)  { super.init(type: type.rawValue, payload: payload)   }
    init(type: StateType, payload8:      UInt8 )  { super.init(type: type.rawValue, payload: payload8)  }
    init(type: StateType, payload16:     UInt16)  { super.init(type: type.rawValue, payload: payload16) }
    init(type: StateType, payload32:     UInt32)  { super.init(type: type.rawValue, payload: payload32) }
    init(type: StateType, payloadArray:  [UInt8]) { super.init(type: type.rawValue, payload: payloadArray) }
    init(type: StateType, payloadFloat:  Float  ) { super.init(type: type.rawValue, payloadFloat: payloadFloat)  }
    
    func getOpCode() -> OpCode {
        return .read
    }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(self.getOpCode().rawValue)
        arr += Conversion.uint16_to_uint8_array(self.length)
        arr += self.payload
        return arr
    }
}

class WriteStatePacket : ReadStatePacket {
    override func getOpCode() -> OpCode { return .write }
}

