//
//  BroadcastPackets.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 13/12/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation
import SwiftyJSON
import CryptoSwift

class BroadcastStone_SwitchPacket {
    var crownstoneId : UInt8
    var state   : UInt8
    
    init(crownstoneId: UInt8, state: UInt8) {
        self.crownstoneId = crownstoneId
        self.state = state
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.crownstoneId)
        arr.append(self.state)
        
        return arr
    }
}


class Broadcast_SetTimePacket {
    var time     : UInt32?
    var suntimes : Broadcast_SunTimePacket
    
    init(time: UInt32, sunrisetSecondsSinceMidnight: UInt32, sunsetSecondsSinceMidnight: UInt32) {
        self.time = time
        self.suntimes = Broadcast_SunTimePacket(sunriseSecondsSinceMidnight: sunrisetSecondsSinceMidnight, sunsetSecondsSinceMidnight: sunsetSecondsSinceMidnight)
    }
    
    init(sunrisetSecondsSinceMidnight: UInt32, sunsetSecondsSinceMidnight: UInt32) {
        self.time = nil
        self.suntimes = Broadcast_SunTimePacket(sunriseSecondsSinceMidnight: sunrisetSecondsSinceMidnight, sunsetSecondsSinceMidnight: sunsetSecondsSinceMidnight)
    }
    
    func getPacket() -> [UInt8] {
        var optionBitmask : UInt8 = 0
        
        // tell the packet how to interpret the data
        optionBitmask += 1 << 0 // time is valid
        optionBitmask += 1 << 1 // sun times are valid
        
        var arr = [UInt8]()
        arr.append(optionBitmask)
        
        if let time = self.time {
            arr += Conversion.uint32_to_uint8_array(time)
        }
        else {
            arr += Conversion.uint32_to_uint8_array(NSNumber(value: getCurrentTimestampForCrownstone()).uint32Value)
        }
        
        arr += self.suntimes.getSunTimeData()
        
        return arr
    }
}


class Broadcast_SunTimePacket {
    var sunriseSecondsSinceMidnight : UInt32
    var sunsetSecondsSinceMidnight  : UInt32
   
    init(sunriseSecondsSinceMidnight: UInt32, sunsetSecondsSinceMidnight: UInt32) {
        self.sunriseSecondsSinceMidnight = sunriseSecondsSinceMidnight
        self.sunsetSecondsSinceMidnight  = sunsetSecondsSinceMidnight
    }
   
    func getSunTimeData() -> [UInt8] {
        let sunriseArray = Conversion.uint32_to_uint8_array(self.sunriseSecondsSinceMidnight)
        let sunsetArray  = Conversion.uint32_to_uint8_array(self.sunsetSecondsSinceMidnight)

        let suntimePacket : [UInt8] = [
            sunriseArray[0], // 0
            sunriseArray[1], // 1
            sunriseArray[2], // 2
            sunsetArray[0],  // 3
            sunsetArray[1],  // 4
            sunsetArray[2],  // 5
        ]

        return suntimePacket
    }
    
    func getPacket() -> [UInt8] {
        var optionBitmask : UInt8 = 0
        
        optionBitmask += 0 << 0 // time is NOT valid
        optionBitmask += 1 << 1 // sun times are valid
        
        var arr = [UInt8]()
    
        arr.append(optionBitmask)
        arr += [0,0,0,0] // this is padding where the time should normally live. This packet should not have time.
        
        arr += self.getSunTimeData()
        
        return arr
    }
}


class Broadcast_ForegroundBasePacket {
    var suntimes : Broadcast_SunTimePacket
    
    init(sunriseSecondsSinceMidnight: UInt32, sunsetSecondsSinceMidnight: UInt32) {
        self.suntimes = Broadcast_SunTimePacket(sunriseSecondsSinceMidnight: sunriseSecondsSinceMidnight, sunsetSecondsSinceMidnight: sunsetSecondsSinceMidnight)
    }
    
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        
        arr += self.suntimes.getPacket()
        arr += [0,0,0,0,0]
        
        return arr
    }
}
