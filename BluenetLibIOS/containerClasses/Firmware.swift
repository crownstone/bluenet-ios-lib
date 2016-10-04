//
//  Firmware.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation


open class Firmware {
    open var softdeviceSize: NSNumber
    open var bootloaderSize: NSNumber
    open var applicationSize: NSNumber
    open var data: [UInt8]
    
    init(softdeviceSize: NSNumber, bootloaderSize: NSNumber, applicationSize: NSNumber, data: [UInt8]) {
        self.softdeviceSize = softdeviceSize
        self.bootloaderSize = bootloaderSize
        self.applicationSize = applicationSize
        self.data = data
    }
    
    open func getSizePacket() -> [UInt8] {
        var result = [UInt8]()
        
        result += Conversion.uint32_to_uint8_array(softdeviceSize.uint32Value)
        result += Conversion.uint32_to_uint8_array(bootloaderSize.uint32Value)
        result += Conversion.uint32_to_uint8_array(applicationSize.uint32Value)
        
        return result
    }
    
}

