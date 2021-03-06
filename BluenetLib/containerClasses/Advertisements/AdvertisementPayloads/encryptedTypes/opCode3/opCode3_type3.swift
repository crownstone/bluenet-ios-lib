//
//  opCode3_type3.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 08/01/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation

func parseOpcode3_type3(serviceData : ScanResponsePacket, data : [UInt8]) {
    if (data.count == 16) {
        parseOpcode3_type1(serviceData: serviceData, data: data)
        
        // apply differences between type 1 and type 4
        serviceData.stateOfExternalCrownstone = true
        serviceData.powerUsageReal = 0
        serviceData.rssiOfExternalCrownstone = Conversion.uint8_to_int8(data[14])
        serviceData.validation = data[15]
    }
}
