//
//  opCode7_type5.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 31/03/2020.
//  Copyright © 2020 Alex de Mulder. All rights reserved.
//

import Foundation


func parseOpcode7_type5(serviceData : ScanResponsePacket, data : [UInt8]) {
    do {
        if (data.count == 16) {
            // dataType = data[0]
            
            let payload = DataStepper(data)
            
            serviceData.hubMode = true
            serviceData.stateOfExternalCrownstone = false
            
            try payload.skip() // first byte is the datatype.
            serviceData.crownstoneId      = try payload.getUInt8()
            serviceData.flagsBitmask      = try payload.getUInt8()
            serviceData.hubData           = try payload.getBytes(9)
            serviceData.partialTimestamp  = try payload.getUInt16()
            try payload.skip()
            serviceData.validation        = try payload.getUInt8()
            
            
            // bitmask states
            let bitmaskArray = Conversion.uint8_to_bit_array(serviceData.flagsBitmask)
            
            serviceData.uartAlive           = bitmaskArray[0]
            serviceData.uartAliveEncrypted  = bitmaskArray[1]
            serviceData.uartEncryptionRequiredByCrownstone = bitmaskArray[2]
            serviceData.uartEncryptionRequiredByHub        = bitmaskArray[3]
            serviceData.hubHasBeenSetup     = bitmaskArray[4]
            serviceData.hubHasInternet      = bitmaskArray[5]
            serviceData.hubHasError         = bitmaskArray[6]
            serviceData.timeSet             = bitmaskArray[7]
          
           
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



