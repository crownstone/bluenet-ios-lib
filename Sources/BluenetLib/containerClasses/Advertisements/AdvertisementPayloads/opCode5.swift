//
//  opCode5.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 05/04/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation

func parseOpcode5(serviceData : ScanResponsePacket, data : [UInt8]) {
    if (data.count == 16) {
        serviceData.dataType = data[0]
        
        switch (serviceData.dataType) {
        case 0:
            parseOpcode3_type0(serviceData: serviceData, data: data)
        case 1:
            parseOpcode3_type1(serviceData: serviceData, data: data)
        case 2:
            parseOpcode3_type2(serviceData: serviceData, data: data)
        case 3:
            parseOpcode3_type3(serviceData: serviceData, data: data)
        case 4:
            parseOpcode7_type4(serviceData: serviceData, data: data)
        case 5:
            parseOpcode7_type5(serviceData: serviceData, data: data)
        default:
            // LOG.warn("Advertisement opCode 3: Got an unknown typeCode \(data[1])")
            parseOpcode3_type0(serviceData: serviceData, data: data)
        }
    }
}
