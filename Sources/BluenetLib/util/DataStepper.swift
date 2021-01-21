//
//  DataStepper.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 20/01/2020.
//  Copyright © 2020 Alex de Mulder. All rights reserved.
//

import Foundation


public class DataStepper {
    var data : [UInt8]!
    var length : Int = 0
    var position : Int = 0
    var markPosition : Int = 0
    
    public init(_ data: [UInt8]) {
        self.data = data
        self.length = self.data.count
    }
    
    public func getBitmask8() throws -> [Bool] {
        let byte = try self._request(1)[0]
        return Conversion.uint8_to_bit_array(byte)
    }
    
    public func getUInt8() throws -> UInt8 {
        return try self._request(1)[0]
    }
    
    public func getInt16() throws -> Int16 {
         let uint16 = Conversion.uint8_array_to_uint16(try self._request(2))
        return Conversion.uint16_to_int16(uint16)
     }
    
    public func getFloat() throws -> Float {
        return Conversion.uint8_array_to_float(try self._request(4))
     }
    
    public func getUInt16() throws -> UInt16 {
        return Conversion.uint8_array_to_uint16(try self._request(2))
    }
    
    public func getUInt32() throws -> UInt32 {
        return Conversion.uint8_array_to_uint32(try self._request(4))
    }
    
    public func getUInt64() throws -> UInt64 {
        return Conversion.uint8_array_to_uint64(try self._request(8))
    }
    
    public func getBytes(_ amount : Int) throws -> [UInt8] {
        return try self._request(amount)
    }
    
    public func getRemainingBytes() throws -> [UInt8] {
        let amount = self.length - self.position
        return try self._request(amount)
    }
    
    public func getBytes(_ amount : UInt16) throws -> [UInt8] {
        let int = NSNumber(value: amount).intValue
        return try self._request(int)
    }
    
    public func mark() {
        self.markPosition = self.position
    }
    
    public func skip(_ count: Int = 1) throws {
        if self.position + count <= self.length {
            self.position += count
        }
        else {
            throw BluenetError.INVALID_DATA_LENGTH
        }
    }
    
    public func reset() {
        self.position = self.markPosition
    }
    
    func _request(_ size : Int) throws -> [UInt8] {
        if self.position + size <= self.length {
            let start = self.position
            self.position += size
            return Array(data[start..<self.position])
        }
        else {
            throw BluenetError.INVALID_DATA_LENGTH
        }
    }
    
}
