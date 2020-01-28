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
    
    public func getUInt8() throws -> UInt8 {
        return try self._request(1)[0]
    }
    
    public func getUInt32() throws -> UInt32 {
        return Conversion.uint8_array_to_uint32(try self._request(4))
    }
    
    public func getUInt64() throws -> UInt64 {
        return Conversion.uint8_array_to_uint64(try self._request(8))
    }
    
    public func mark() {
        self.markPosition = self.position
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
