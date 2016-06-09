//
//  packets.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 09/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

// Convert a number into an array of 2 bytes.
func uint16_to_uint8_array(value: UInt16) -> [UInt8] {
    return [
        UInt8((value >> 0 & 0xFF)),
        UInt8((value >> 8 & 0xFF))
    ]
}

// Convert a number into an array of 4 bytes.
func uint32_to_uint8_array(value: UInt32) -> [UInt8] {
    return [
        UInt8((value >> 0 & 0xFF)),
        UInt8((value >> 8 & 0xFF)),
        UInt8((value >> 16 & 0xFF)),
        UInt8((value >> 24 & 0xFF))
    ]
}

func string_to_uint8_array(string: String) -> [UInt8] {
    var arr = [UInt8]();
    for c in string.characters {
        let scalars = String(c).unicodeScalars
        arr.append(UInt8(scalars[scalars.startIndex].value))
    }
    return arr
}

class BLEPacket {
    var type : UInt8 = 0
    var length : [UInt8] = [0,0]
    var payload = [UInt8]()
    
    init(type: UInt8, payload: String) {
        self.type = type
        self.payload = string_to_uint8_array(payload)
        self.length = uint16_to_uint8_array(__uint16_t(self.payload.count))
    }
    
    init(type: UInt8, payload: UInt8) {
        self.type = type
        self.payload = [payload]
        self.length = uint16_to_uint8_array(__uint16_t(self.payload.count))
    }
    
    init(type: UInt8, payload: UInt16) {
        self.type = type
        self.payload = uint16_to_uint8_array(payload)
        self.length = uint16_to_uint8_array(__uint16_t(self.payload.count))
    }
    
    init(type: UInt8, payload: UInt32) {
        self.type = type
        self.payload = uint32_to_uint8_array(payload)
        self.length = uint16_to_uint8_array(__uint16_t(self.payload.count))
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(0)
        arr += self.length
        arr += self.payload
        return arr
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