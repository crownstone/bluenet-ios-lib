//
//  PowerSamples.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 22/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

/**
 * Wrapper for all relevant data of the object
 *
 */


class PowerSamples {
     
    var type           : UInt8
    var index          : UInt8
    var count          : UInt16
    var timestamp      : UInt32
    var delay          : UInt16
    var sampleInterval : UInt16
    var reserved       : UInt16
    var offset         : Int16
    var multiplier     : Float32
    var samples        : [NSNumber]
    

    init(_ dataBlob: [UInt8]) throws {
        let stepper = DataStepper(dataBlob)
        
        self.type           = try stepper.getUInt8()
        self.index          = try stepper.getUInt8()
        self.count          = try stepper.getUInt16()
        self.timestamp      = try stepper.getUInt32()
        self.delay          = try stepper.getUInt16()
        self.sampleInterval = try stepper.getUInt16()
        self.reserved       = try stepper.getUInt16()
        self.offset         = try stepper.getInt16()
        self.multiplier     = try stepper.getFloat()
        self.samples        = [NSNumber]()

        for _ in [Int](0...(NSNumber(value:self.count).intValue)-1) {
            self.samples.append(NSNumber(value: try stepper.getInt16()))
        }
    }
    
    func getDict() -> Dictionary<String, Any> {
        // to calculate the correct value of the sample:
        // multiplier * (sample - offset)
        return [
            "type":           NSNumber(value: self.type),
            "index":          NSNumber(value: self.index),
            "count":          NSNumber(value: self.count),
            "timestamp":      NSNumber(value: self.timestamp),
            "delay":          NSNumber(value: self.delay),
            "sampleInterval": NSNumber(value: self.delay),
            "offset":         NSNumber(value: self.offset),
            "multiplier":     NSNumber(value: self.multiplier),
            "samples":        samples,
        ]
    }
    
}
