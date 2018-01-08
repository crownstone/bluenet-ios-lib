//
//  opCode4_type0.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 08/01/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation

func parseOpcode4_type0(serviceData : ScanResponcePacket, data : [UInt8]) {
    if (data.count == 17) {
        // opCode   = data[0]
        // dataType = data[1]
        
        serviceData.switchState  = data[2]
        serviceData.flagsBitmask = data[3]
        serviceData.temperature  = Conversion.uint8_to_int8(data[4])
        
        let powerFactor = Conversion.uint8_to_int8(data[5])
        let realPower = Conversion.uint16_to_int16(
            Conversion.uint8_array_to_uint16([
                data[6],
                data[7]
            ])
        )
        
        serviceData.powerFactor        = NSNumber(value: powerFactor).doubleValue / 127
        serviceData.powerUsageReal     = NSNumber(value: realPower).doubleValue / 8
        serviceData.powerUsageApparent = serviceData.powerUsageReal / serviceData.powerFactor
        
        serviceData.errorsBitmask = Conversion.uint8_array_to_uint32([
            data[8],
            data[9],
            data[10],
            data[11]
        ])
        
        serviceData.uniqueIdentifier = NSNumber(value: data[12])
        
        // bitmask states
        let bitmaskArray = Conversion.uint8_to_bit_array(serviceData.flagsBitmask)
        serviceData.dimmingAvailable = bitmaskArray[0]
        serviceData.dimmingAllowed   = bitmaskArray[1]
        serviceData.hasError         = bitmaskArray[2]
        serviceData.switchLocked     = bitmaskArray[3]
    }
}
