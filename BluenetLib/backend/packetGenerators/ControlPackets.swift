//
//  ControlHandler.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

open class ControlPacketsGenerator {
    
    open static func getFactoryResetPacket() -> [UInt8] {
        return Conversion.reverse(Conversion.hex_string_to_uint8_array("deadbeef"));
    }
    
    open static func getSetSchedulePacket(data: [UInt8]) -> [UInt8] {
        return ControlPacket(type: .schedule_ENTRY, payloadArray: data).getPacket()
    }
    
    open static func getScheduleRemovePacket(timerIndex: UInt8) -> [UInt8] {
        return ControlPacket(type: .schedule_REMOVE, payload8: timerIndex).getPacket()
    }
    
    open static func getCommandFactoryResetPacket() -> [UInt8] {
        return FactoryResetPacket().getPacket()
    }
    
    open static func getSwitchStatePacket(_ state: Float) -> [UInt8] {
        let switchState = min(1,max(0,state))*100
        
        let packet = ControlPacket(type: .switch, payload8: NSNumber(value: switchState as Float).uint8Value)
        return packet.getPacket()
    }
    
    open static func getResetPacket() -> [UInt8] {
        return ControlPacket(type: .reset).getPacket()
    }
    
    open static func getPutInDFUPacket() -> [UInt8] {
        return ControlPacket(type: .goto_DFU).getPacket()
    }
    
    open static func getDisconnectPacket() -> [UInt8] {
        return ControlPacket(type: .disconnect).getPacket()
    }
    
    open static func getRelaySwitchPacket(_ state: UInt8) -> [UInt8] {
        return ControlPacket(type: .relay, payload8: state).getPacket()
    }
    
    open static func getPwmSwitchPacket(_ state: Float) -> [UInt8] {
        let switchState = min(1,max(0,state))*100
        return ControlPacket(type: .pwm, payload8: NSNumber(value: switchState as Float).uint8Value).getPacket()
    }
    
    open static func getKeepAliveStatePacket(changeState: Bool, state: Float, timeout: UInt16) -> [UInt8] {
        let switchState = min(1,max(0,state))*100
        
        // make sure we do not
        var actionState : UInt8 = 0
        if (changeState == true) {
            actionState = 1
        }
        
        return keepAliveStatePacket(action: actionState, state: NSNumber(value: switchState as Float).uint8Value, timeout: timeout).getPacket()
    }
    
    open static func getKeepAliveRepeatPacket() -> [UInt8] {
        return ControlPacket(type: .keepAliveRepeat).getPacket()
    }
    
    open static func getResetErrorPacket(errorMask: UInt32) -> [UInt8] {
        return ControlPacket(type: .reset_ERRORS, payload32: errorMask).getPacket()
    }
    
    open static func getSetTimePacket(_ time: UInt32) -> [UInt8] {
        return ControlPacket(type: .set_TIME, payload32: time).getPacket()
    }
    
    open static func getAllowDimmingPacket(_ allow: Bool) -> [UInt8] {
        var allowValue : UInt8 = 0
        if (allow) {
            allowValue = 1
        }
        
        return ControlPacket(type: .allow_dimming, payload8: allowValue).getPacket()
    }
    
    open static func getLockSwitchPacket(_ lock: Bool) -> [UInt8] {
        var lockValue : UInt8 = 0
        if (lock) {
            lockValue = 1
        }
        
        return ControlPacket(type: .lock_switch, payload8: lockValue).getPacket()
    }

}
