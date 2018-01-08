//
//  opCode3_type0.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 08/01/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation

func parseOpcode3_type0(serviceData : ScanResponcePacket, data : [UInt8]) {
    if (data.count == 17) {
        // opCode   = data[0]
        // dataType = data[1]
        
        serviceData.crownstoneId = data[2]
        serviceData.switchState  = data[3]
        serviceData.flagsBitmask = data[4]
        serviceData.temperature  = Conversion.uint8_to_int8(data[5])
        
        let powerFactor = Conversion.uint8_to_int8(data[6])
        let realPower = Conversion.uint16_to_int16(
            Conversion.uint8_array_to_uint16([
                data[7],
                data[8]
            ])
        )
        
        serviceData.powerFactor        = NSNumber(value: powerFactor).doubleValue / 127
        serviceData.powerUsageReal     = NSNumber(value: realPower).doubleValue / 8
        serviceData.powerUsageApparent = serviceData.powerUsageReal / serviceData.powerFactor
        
        serviceData.accumulatedEnergy = Conversion.uint32_to_int32(
            Conversion.uint8_array_to_uint32([
                data[9],
                data[10],
                data[11],
                data[12]
            ])
        )
        serviceData.partialTimestamp = Conversion.uint8_array_to_uint16([data[13],data[14]])
        serviceData.timestamp = NSNumber(value: reconstructTimestamp(currentTimestamp: NSDate().timeIntervalSince1970, LsbTimestamp: serviceData.partialTimestamp)).uint32Value
        
        serviceData.validation = Conversion.uint8_array_to_uint16([data[15],data[16]])
        
        serviceData.uniqueIdentifier = NSNumber(value: serviceData.timestamp)
        
        // bitmask states
        let bitmaskArray = Conversion.uint8_to_bit_array(serviceData.flagsBitmask)
        
        serviceData.dimmingAvailable = bitmaskArray[0]
        serviceData.dimmingAllowed   = bitmaskArray[1]
        serviceData.hasError         = bitmaskArray[2]
        serviceData.switchLocked     = bitmaskArray[3]
    }
}



