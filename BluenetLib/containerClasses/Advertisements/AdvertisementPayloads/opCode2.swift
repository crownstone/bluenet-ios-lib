//
//  opCode2.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 08/01/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation

func parseOpcode2(serviceData : ScanResponsePacket, data : [UInt8]) {
    if (data.count == 17) {
        serviceData.crownstoneId = NSNumber(value: Conversion.uint8_array_to_uint16([data[1], data[2]])).uint8Value
        serviceData.switchState  = data[3]
        serviceData.flagsBitmask = data[4]
        serviceData.temperature  = Conversion.uint8_to_int8(data[5])
        
        let powerFactor = Conversion.uint16_to_int16(
            Conversion.uint8_array_to_uint16([
                data[6],
                data[7]
            ])
        )
        let appearentPower = Conversion.uint16_to_int16(
            Conversion.uint8_array_to_uint16([
                data[8],
                data[9]
            ])
        )
        
        serviceData.powerFactor        = NSNumber(value: powerFactor as Int16).doubleValue / 1024
        serviceData.powerUsageApparent = NSNumber(value: appearentPower as Int16).doubleValue / 16
        serviceData.powerUsageReal     = serviceData.powerFactor * serviceData.powerUsageApparent
        
        serviceData.accumulatedEnergy = Conversion.uint32_to_int32(
            Conversion.uint8_array_to_uint32([
                data[10],
                data[11],
                data[12],
                data[13]
            ])
        )
        
        serviceData.timestamp = Conversion.uint8_array_to_uint32([0x00,data[14],data[15],data[16]])
        serviceData.uniqueIdentifier = NSNumber(value: serviceData.timestamp)
        // bitmask states
        let bitmaskArray = Conversion.uint8_to_bit_array(serviceData.flagsBitmask)
        
        serviceData.stateOfExternalCrownstone = bitmaskArray[1]
        serviceData.hasError                  = bitmaskArray[2]
        serviceData.setupMode                 = bitmaskArray[7]
    }
}
