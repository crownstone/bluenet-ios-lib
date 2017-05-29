//
//  CrownstoneErrors.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 23/05/2017.
//  Copyright © 2017 Alex de Mulder. All rights reserved.
//

import Foundation


/**
 * Wrapper for all relevant data of the object
 *
 */
open class CrownstoneErrors {
    open var overCurrent        = false
    open var overCurrentDimmer  = false
    open var temperatureChip    = false
    open var temperatureDimmer  = false
    
    open var bitMask : UInt32 = 0
    
    init(bitMask: UInt32) {
        self.bitMask = bitMask
        
        let bitArray = Conversion.uint32_to_bit_array(bitMask)
        
        overCurrent       = bitArray[31-0]
        overCurrentDimmer = bitArray[31-1]
        temperatureChip   = bitArray[31-2]
        temperatureDimmer = bitArray[31-3]
    }
    
    init(dictionary: NSDictionary) {
        self.overCurrent =       ((dictionary["overCurrent"]       as? Bool) != nil) || false
        self.overCurrentDimmer = ((dictionary["overCurrentDimmer"] as? Bool) != nil) || false
        self.temperatureChip =   ((dictionary["temperatureChip"]   as? Bool) != nil) || false
        self.temperatureDimmer = ((dictionary["temperatureDimmer"] as? Bool) != nil) || false
        
        var bitArray = [Bool](repeating: false, count: 32)
        bitArray[31-0] = self.overCurrent
        bitArray[31-1] = self.overCurrentDimmer
        bitArray[31-2] = self.temperatureChip
        bitArray[31-3] = self.temperatureDimmer
        
        self.bitMask = Conversion.bit_array_to_uint32(bitArray)
    }
    
    open func getResetMask() -> UInt32 {
        let bitArray = Conversion.uint32_to_bit_array(self.bitMask)
        let flippedArray = Conversion.flip_bit_array(bitArray)
        
        let flippedMask = Conversion.bit_array_to_uint32(flippedArray)
        return flippedMask
    }
    
    open func hasErrors() -> Bool {
        return self.bitMask == 0
    }
    
    open func getDictionary() -> NSDictionary {
        let returnDict : [String: Any] = [
            "overCurrent" : NSNumber(value: self.overCurrent),
            "overCurrentDimmer" : NSNumber(value: self.overCurrentDimmer),
            "temperatureChip" : NSNumber(value: self.temperatureChip),
            "temperatureDimmer" : NSNumber(value: self.temperatureDimmer),
            "bitMask" : NSNumber(value: self.bitMask),
        ]
        
        return returnDict as NSDictionary
    }
    
  }




