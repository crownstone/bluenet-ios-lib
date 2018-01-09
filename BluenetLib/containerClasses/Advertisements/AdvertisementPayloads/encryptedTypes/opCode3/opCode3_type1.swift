//
//  opCode3_type1.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 08/01/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation

func parseOpcode3_type1(serviceData : ScanResponsePacket, data : [UInt8], includePowerMeasurement : Bool = true) {
    if (data.count == 17) {
        // opCode   = data[0]
        // dataType = data[1]
        serviceData.errorMode = true
        
        serviceData.crownstoneId  = data[2]
        serviceData.errorsBitmask = Conversion.uint8_array_to_uint32([
            data[3],
            data[4],
            data[5],
            data[6]
        ])
        
        serviceData.errorTimestamp = Conversion.uint8_array_to_uint32([
            data[7],
            data[8],
            data[9],
            data[10]
        ])
        
        serviceData.flagsBitmask = data[11]
        serviceData.temperature  = Conversion.uint8_to_int8(data[12])

        serviceData.partialTimestamp = Conversion.uint8_array_to_uint16([data[13],data[14]])
        serviceData.timestamp = NSNumber(value: reconstructTimestamp(currentTimestamp: NSDate().timeIntervalSince1970, LsbTimestamp: serviceData.partialTimestamp)).uint32Value
        serviceData.uniqueIdentifier = NSNumber(value: serviceData.timestamp)
        
        // bitmask states
        let bitmaskArray = Conversion.uint8_to_bit_array(serviceData.flagsBitmask)
        
        serviceData.dimmingAvailable = bitmaskArray[0]
        serviceData.dimmingAllowed   = bitmaskArray[1]
        serviceData.hasError         = bitmaskArray[2]
        serviceData.switchLocked     = bitmaskArray[3]
        
        // opt out of this for the opcode3, type 4: external error state
        if (includePowerMeasurement) {
            let realPower = Conversion.uint16_to_int16(
                Conversion.uint8_array_to_uint16([
                    data[15],
                    data[16]
                    ])
            )
            serviceData.powerUsageReal     = NSNumber(value: realPower).doubleValue / 8
        }
    }
}
