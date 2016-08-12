//
//  Conversion.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 15/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

public class Conversion {
    
    // Convert a number into an array of 2 bytes.
    public static func uint16_to_uint8_array(value: UInt16) -> [UInt8] {
        return [
            UInt8((value >> 0 & 0xFF)),
            UInt8((value >> 8 & 0xFF))
        ]
    }
    
    // Convert a number into an array of 4 bytes.
    public static func uint32_to_uint8_array(value: UInt32) -> [UInt8] {
        return [
            UInt8((value >> 0 & 0xFF)),
            UInt8((value >> 8 & 0xFF)),
            UInt8((value >> 16 & 0xFF)),
            UInt8((value >> 24 & 0xFF))
        ]
    }
    
    public static func string_to_uint8_array(string: String) -> [UInt8] {
        var arr = [UInt8]();
        for c in string.characters {
            let scalars = String(c).unicodeScalars
            arr.append(UInt8(scalars[scalars.startIndex].value))
        }
        return arr
    }
    
    public static func uint8_array_to_string(data: [UInt8]) -> String {
        var stringResult = ""
        for byte in data {
            stringResult += Conversion.uint8_to_hex_string(byte)
        }
        return stringResult
    }
    
    public static func uint8_to_hex_string(byte: UInt8) -> String {
        return String(format:"%2X", byte)
    }
    
    public static func hex_string_to_uint8_array(input: String) -> [UInt8] {
        var hexNumber = ""
        var result = [UInt8]()
        for letter in input.characters {
            hexNumber += String(letter)
            if (hexNumber.characters.count == 2) {
                result.append(UInt8(hexNumber,radix:16)!)
                hexNumber = ""
            }
        }
        return result
    }
    
    public static func ibeaconUUIDString_to_uint8_array(input:String) -> [UInt8] {
        let check = NSUUID(UUIDString: input)
        if (check != nil) {
            var stripped = input.stringByReplacingOccurrencesOfString("-", withString: "")
            stripped  = stripped.stringByReplacingOccurrencesOfString(":", withString: "")
            return Conversion.hex_string_to_uint8_array(stripped)
        }
        return []
    }
    
    public static func uint8_array_to_uint16(arr8: [UInt8]) -> UInt16 {
        return (UInt16(arr8[1]) << 8) + UInt16(arr8[0])
    }
    
    public static func uint8_array_to_uint32(arr8: [UInt8]) -> UInt32 {
        let p1 = UInt32(arr8[3]) << 24
        let p2 = UInt32(arr8[2]) << 16
        let p3 = UInt32(arr8[1]) << 8
        let p4 = UInt32(arr8[0])
        return p1 + p2 + p3 + p4
    }
    
    public static func uint32_to_int32(val: UInt32) -> Int32 {
        let ns = NSNumber(unsignedInt: val)
        return ns.intValue
    }
    
    
    public static func uint8_to_int8(val: UInt8) -> Int8 {
        let ns = NSNumber(unsignedChar: val)
        return ns.charValue
    }
}