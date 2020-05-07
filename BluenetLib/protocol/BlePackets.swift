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

let PROTOCOL_VERSION_V5 : UInt8 = 5

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


class BLEPacketV3 : BLEPacketBase {
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

class ControlPacketV3 : BLEPacketV3 {
   
    init(type: ControlTypeV3)                    { super.init(type: type.rawValue)  }
    init(type: ControlTypeV3, payload:   String) { super.init(type: type.rawValue, payload: payload)   }
    init(type: ControlTypeV3, payload8:  UInt8)  { super.init(type: type.rawValue, payload: payload8)  }
    init(type: ControlTypeV3, payload16: UInt16) { super.init(type: type.rawValue, payload: payload16) }
    init(type: ControlTypeV3, payload32: UInt32) { super.init(type: type.rawValue, payload: payload32) }
    init(type: ControlTypeV3, payloadArray: [UInt8]) { super.init(type: type.rawValue, payload: payloadArray) }
    init(type: ControlTypeV3, payloadFloat: Float) { super.init(type: type.rawValue, payload: payloadFloat) }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr += Conversion.uint16_to_uint8_array(self.type)
        arr += Conversion.uint16_to_uint8_array(self.length)
        arr += self.payload
        return arr
    }
}

class ControlPacketV5 : ControlPacketV3 {
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(PROTOCOL_VERSION_V5)
        arr += Conversion.uint16_to_uint8_array(self.type)
        arr += Conversion.uint16_to_uint8_array(self.length)
        arr += self.payload
        return arr
    }
}

class ControlStateSetPacket : ControlPacketV3 {
    
    var stateType : UInt16
    var id : UInt16
    
    init(type: StateTypeV3, id: UInt16 = 0)                        { self.id = id; self.stateType = type.rawValue; super.init(type: ControlTypeV3.setState)  }
    init(type: StateTypeV3, payload:   String,     id: UInt16 = 0) { self.id = id; self.stateType = type.rawValue; super.init(type: ControlTypeV3.setState, payload: payload)   }
    init(type: StateTypeV3, payload8:  UInt8,      id: UInt16 = 0) { self.id = id; self.stateType = type.rawValue; super.init(type: ControlTypeV3.setState, payload8: payload8)  }
    init(type: StateTypeV3, payload16: UInt16,     id: UInt16 = 0) { self.id = id; self.stateType = type.rawValue; super.init(type: ControlTypeV3.setState, payload16: payload16) }
    init(type: StateTypeV3, payload32: UInt32,     id: UInt16 = 0) { self.id = id; self.stateType = type.rawValue; super.init(type: ControlTypeV3.setState, payload32: payload32) }
    init(type: StateTypeV3, payloadArray: [UInt8], id: UInt16 = 0) { self.id = id; self.stateType = type.rawValue; super.init(type: ControlTypeV3.setState, payloadArray: payloadArray) }
    init(type: StateTypeV3, payloadFloat: Float,   id: UInt16 = 0) { self.id = id; self.stateType = type.rawValue; super.init(type: ControlTypeV3.setState, payloadFloat: payloadFloat) }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr += Conversion.uint16_to_uint8_array(self.type)
        arr += Conversion.uint16_to_uint8_array(self.length + 4) // the + 2 is for the stateType uint16 and +2 for the ID, this makes +4
        arr += Conversion.uint16_to_uint8_array(self.stateType)
        arr += Conversion.uint16_to_uint8_array(self.id)
        arr += self.payload
        return arr
    }
}

class ControlStateSetPacketV5 : ControlStateSetPacket {
    var persistence : SetPersistenceMode = .STORED
    
    init(type: StateTypeV3,                        id: UInt16 = 0, persistence: SetPersistenceMode = .STORED) { self.persistence = persistence; super.init(type: type, id: id);                             self.id = id; self.stateType = type.rawValue; }
    init(type: StateTypeV3, payload:   String,     id: UInt16 = 0, persistence: SetPersistenceMode = .STORED) { self.persistence = persistence; super.init(type: type, payload: payload, id: id);           self.id = id; self.stateType = type.rawValue; }
    init(type: StateTypeV3, payload8:  UInt8,      id: UInt16 = 0, persistence: SetPersistenceMode = .STORED) { self.persistence = persistence; super.init(type: type, payload8: payload8, id: id);         self.id = id; self.stateType = type.rawValue; }
    init(type: StateTypeV3, payload16: UInt16,     id: UInt16 = 0, persistence: SetPersistenceMode = .STORED) { self.persistence = persistence; super.init(type: type, payload16: payload16, id: id);       self.id = id; self.stateType = type.rawValue; }
    init(type: StateTypeV3, payload32: UInt32,     id: UInt16 = 0, persistence: SetPersistenceMode = .STORED) { self.persistence = persistence; super.init(type: type, payload32: payload32, id: id);       self.id = id; self.stateType = type.rawValue; }
    init(type: StateTypeV3, payloadArray: [UInt8], id: UInt16 = 0, persistence: SetPersistenceMode = .STORED) { self.persistence = persistence; super.init(type: type, payloadArray: payloadArray, id: id); self.id = id; self.stateType = type.rawValue; }
    init(type: StateTypeV3, payloadFloat: Float,   id: UInt16 = 0, persistence: SetPersistenceMode = .STORED) { self.persistence = persistence; super.init(type: type, payloadFloat: payloadFloat, id: id); self.id = id; self.stateType = type.rawValue; }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(PROTOCOL_VERSION_V5)
        arr += Conversion.uint16_to_uint8_array(self.type)
        arr += Conversion.uint16_to_uint8_array(self.length + 6) // the + 2 is for the stateType uint16 and +2 for the ID and +2 for the persistence mode
        arr += Conversion.uint16_to_uint8_array(self.stateType)
        arr += Conversion.uint16_to_uint8_array(self.id)
        
        arr.append(self.persistence.rawValue)
        arr.append(0) //reserved
        
        arr += self.payload
        return arr
    }
}


// this class is meant as backwards compatibility and has no id field. The old state enums have the same value as the new ones.
class ControlStateGetPacket : ControlPacketV3 {
    init(type: StateTypeV3) { super.init(type: ControlTypeV3.getState, payload16: type.rawValue)  }
}

class ControlStateGetPacketV3 : ControlPacketV3 {
    var id : UInt16 = 0
    
    init(type: StateTypeV3, id: UInt16) {
        super.init(type: ControlTypeV3.getState, payload16: type.rawValue)
        self.id = id
    }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr += Conversion.uint16_to_uint8_array(self.type)       // this is the command type
        arr += Conversion.uint16_to_uint8_array(self.length + 2) // 2 for the ID size
        arr += self.payload                                      // this is the state type
        arr += Conversion.uint16_to_uint8_array(self.id)
        return arr
    }
}

class ControlStateGetPacketV5 : ControlStateGetPacketV3 {
    var persistence : GetPersistenceMode = .CURRENT
    
    init(type: StateTypeV3, id: UInt16 = 0, persistence: GetPersistenceMode = .CURRENT) {
        super.init(type: type, id: id)
        self.persistence = persistence
    }
    
    override func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(PROTOCOL_VERSION_V5)
        arr += Conversion.uint16_to_uint8_array(self.type)       // this is the command type
        arr += Conversion.uint16_to_uint8_array(self.length + 4) // 2 for the ID size, 2 for the persistence mode size
        arr += self.payload                                      // this is the state type
        arr += Conversion.uint16_to_uint8_array(self.id)
        
        arr.append(self.persistence.rawValue)
        arr.append(0) //reserved
        return arr
    }
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

class FactoryResetPacketV3 : ControlPacketV3 {
    init() {super.init(type: ControlTypeV3.factory_RESET, payload32: 0xdeadbeef)}
}
class FactoryResetPacketV5 : ControlPacketV5 {
    init() {super.init(type: ControlTypeV3.factory_RESET, payload32: 0xdeadbeef)}
}


class EnableScannerPacket : ControlPacket {
    init(payload8: UInt8) {super.init(type: ControlType.enable_SCANNER, payload8: payload8)}
}

class EnableScannerDelayPacket : ControlPacket {
    init(delayInMs: Int) {super.init(type: ControlType.enable_SCANNER, payload16: UInt16(delayInMs))}
}

// LEGACY
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
// LEGACY
class WriteConfigPacket : ReadConfigPacket {
    override func getOpCode() -> OpCode { return .write }
}


// LEGACY
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
// LEGACY
class WriteStatePacket : ReadStatePacket {
    override func getOpCode() -> OpCode { return .write }
}

