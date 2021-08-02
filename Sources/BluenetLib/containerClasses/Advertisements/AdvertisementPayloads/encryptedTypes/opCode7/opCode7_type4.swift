//
//  opCode7_type4.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 31/03/2020.
//  Copyright © 2020 Alex de Mulder. All rights reserved.
//

import Foundation


func parseOpcode7_type4(serviceData : ScanResponsePacket, data : [UInt8]) {
    do {
        if (data.count == 16) {
            // dataType = data[0]
            
            let payload = DataStepper(data)
            
            serviceData.stateOfExternalCrownstone = false
            serviceData.alternativeState = true
            
            try payload.skip() // first byte is the datatype.
            serviceData.crownstoneId         = try payload.getUInt8()
            serviceData.switchState          = try payload.getUInt8()
            serviceData.flagsBitmask         = try payload.getUInt8()
            serviceData.behaviourMasterHash  = try payload.getUInt16() // Still fletcher
            serviceData.assetFiltersMasterVersion  = try payload.getUInt16()
            serviceData.assetFiltersCRC      = try payload.getUInt32() // crc32
        
            serviceData.partialTimestamp     = try payload.getUInt16()
            try payload.skip()
            serviceData.validation           = try payload.getUInt8()
            
            // bitmask states
            let bitmaskArray = Conversion.uint8_to_bit_array(serviceData.flagsBitmask)
            
            serviceData.dimmerReady         = bitmaskArray[0]
            serviceData.dimmingAllowed      = bitmaskArray[1]
            serviceData.hasError            = bitmaskArray[2]
            serviceData.switchLocked        = bitmaskArray[3]
            serviceData.timeSet             = bitmaskArray[4]
            serviceData.switchCraftEnabled  = bitmaskArray[5]
            serviceData.tapToToggleEnabled  = bitmaskArray[6]
            serviceData.behaviourOverridden = bitmaskArray[7]            
           
            serviceData.uniqueIdentifier = NSNumber(value: serviceData.partialTimestamp)
            
            if (serviceData.timeSet) {
                serviceData.timestamp = NSNumber(value: reconstructTimestamp(currentTimestamp: NSDate().timeIntervalSince1970, LsbTimestamp: serviceData.partialTimestamp)).doubleValue
            }
            else {
                serviceData.timestamp = NSNumber(value: serviceData.partialTimestamp).doubleValue // this is now a counter
            }
        }
    }
    catch {}
}



