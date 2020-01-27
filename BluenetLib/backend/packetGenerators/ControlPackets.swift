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



 public class ControlPacketsGeneratorClass {
    var controlVersion : ControlVersionType = .v1
    
    init() {}
    
     func getFactoryResetPacket() -> [UInt8] {
        return Conversion.reverse(Conversion.hex_string_to_uint8_array("deadbeef"));
    }
    
    
    /** LEGACY **/
     func getSetSchedulePacket(data: [UInt8]) -> [UInt8] {
        return ControlPacket(type: .schedule_ENTRY, payloadArray: data).getPacket()
    }
    
    /** LEGACY **/
     func getScheduleRemovePacket(timerIndex: UInt8) -> [UInt8] {
        return ControlPacket(type: .schedule_REMOVE, payload8: timerIndex).getPacket()
    }
    
     func getCommandFactoryResetPacket() -> [UInt8] {
        if controlVersion == .v2 { return FactoryResetPacketV2().getPacket()}
        else                     { return FactoryResetPacket().getPacket()}
    }
    
     func getSwitchStatePacket(_ state: Float) -> [UInt8] {
        let switchState = min(1,max(0,state))*100
        
        if controlVersion == .v2 { return ControlPacketV2(type: .switch, payload8: NSNumber(value: switchState as Float).uint8Value).getPacket()}
        else                     { return ControlPacket(  type: .switch, payload8: NSNumber(value: switchState as Float).uint8Value).getPacket() }
        
    }
    
     func getResetPacket() -> [UInt8] {
        if controlVersion == .v2 { return ControlPacketV2(type: .reset).getPacket()}
        else                     { return ControlPacket(  type: .reset).getPacket()}
    }
    
     func getPutInDFUPacket() -> [UInt8] {
        if controlVersion == .v2 { return ControlPacketV2(type: .goto_DFU).getPacket()}
        else                     { return ControlPacket(  type: .goto_DFU).getPacket()}
    }
    
     func getDisconnectPacket() -> [UInt8] {
        if controlVersion == .v2 { return ControlPacketV2(type: .disconnect).getPacket()}
        else                     { return ControlPacket(  type: .disconnect).getPacket()}
    }
    
     func getRelaySwitchPacket(_ state: UInt8) -> [UInt8] {
        if controlVersion == .v2 { return ControlPacketV2(type: .relay, payload8: state).getPacket()}
        else                     { return ControlPacket(  type: .relay, payload8: state).getPacket()}
    }
    
     func getPwmSwitchPacket(_ state: Float) -> [UInt8] {
        let switchState : UInt8 = NSNumber(value: min(1,max(0,state))*100).uint8Value
        
        if controlVersion == .v2 { return ControlPacketV2(type: .pwm, payload8: switchState).getPacket()}
        else                     { return ControlPacket(  type: .pwm, payload8: switchState).getPacket()}
    }
    
    /** LEGACY **/
     func getKeepAliveStatePacket(changeState: Bool, state: Float, timeout: UInt16) -> [UInt8] {
        let switchState = min(1,max(0,state))*100
        
        // make sure we do not
        var actionState : UInt8 = 0
        if (changeState == true) {
            actionState = 1
        }
        
        return KeepAliveStatePacket(action: actionState, state: NSNumber(value: switchState as Float).uint8Value, timeout: timeout).getPacket()
    }
    
    /** LEGACY **/
     func getKeepAliveRepeatPacket() -> [UInt8] {
        return ControlPacket(type: .keepAliveRepeat).getPacket()
    }
    
     func getResetErrorPacket(errorMask: UInt32) -> [UInt8] {
        if controlVersion == .v2 { return ControlPacketV2(type: .reset_ERRORS, payload32: errorMask).getPacket()}
        else                     { return ControlPacket(  type: .reset_ERRORS, payload32: errorMask).getPacket()}
    }
    
     func getSetTimePacket(_ time: UInt32) -> [UInt8] {
        if controlVersion == .v2 { return ControlPacketV2(type: .set_TIME, payload32: time).getPacket()}
        else                     { return ControlPacket(  type: .set_TIME, payload32: time).getPacket()}
    }
    
     func getNoOpPacket() -> [UInt8] {
        if controlVersion == .v2 { return ControlPacketV2(type: .no_OPERATION).getPacket()}
        else                     { return ControlPacket(  type: .no_OPERATION).getPacket()}
    }
    
     func getAllowDimmingPacket(_ allow: Bool) -> [UInt8] {
        var allowValue : UInt8 = 0
        if (allow) {
            allowValue = 1
        }
        if controlVersion == .v2 { return ControlPacketV2(type: .allow_dimming, payload8: allowValue).getPacket()}
        else                     { return ControlPacket(  type: .allow_dimming, payload8: allowValue).getPacket()}
    }
    
     func getLockSwitchPacket(_ lock: Bool) -> [UInt8] {
        var lockValue : UInt8 = 0
        if (lock) {
            lockValue = 1
        }
        
        if controlVersion == .v2 { return ControlPacketV2(type: .lock_switch, payload8: lockValue).getPacket()}
        else                     { return ControlPacket(  type: .lock_switch, payload8: lockValue).getPacket()}
    }
    
     func getSwitchCraftPacket(_ enabled: Bool) -> [UInt8] {
        var enabledValue : UInt8 = 0
        if (enabled) {
            enabledValue = 1
        }
        
        if controlVersion == .v2 { return ControlStateSetPacket(type: .SWITCHCRAFT_ENABLED, payload8: enabledValue).getPacket()}
        else                     { return ControlPacket(  type: .enable_switchcraft, payload8: enabledValue).getPacket()}
    }
    
    func getMeshCommandPacket(commandPacket: [UInt8]) -> [UInt8] {
        if controlVersion == .v2 { return ControlPacketV2(type: .mesh_command, payloadArray: commandPacket).getPacket()}
        else                     { return ControlPacket(  type: .mesh_command, payloadArray: commandPacket).getPacket()}
    }
    
    
    func getTurnOnPacket(stones:[[String: NSNumber]]) -> [UInt8] {
        if controlVersion == .v2 {
            var innerPacket = [UInt8]()
            var count : UInt8 = 0
            for stone in stones {
                let crownstoneId  = stone["crownstoneId"]
                let state : UInt8 = 255
                
                if (crownstoneId != nil) {
                    innerPacket.append(crownstoneId!.uint8Value)
                    innerPacket.append(state)
                    count += 1
                }
            }
            
            var packet = [UInt8]()
            packet.append(count)
            packet += innerPacket
            
            return ControlPacketV2(type: .multiSwitch, payloadArray: packet).getPacket()
        }
        else {
            return ControlPacketsGenerator.getMultiSwitchPacket(stones: stones)
        }
    }
    
    func getMultiSwitchPacket(stones:[[String: NSNumber]]) -> [UInt8] {
        if controlVersion == .v2 {
            var innerPacket = [UInt8]()
            var count : UInt8 = 0
            for stone in stones {
                let crownstoneId = stone["crownstoneId"]
                let state        = stone["state"]
                
                if (crownstoneId != nil && state != nil) {
                    innerPacket.append(crownstoneId!.uint8Value)
                    innerPacket.append(state!.uint8Value)
                    count += 1
                }
            }
            
            var packet = [UInt8]()
            packet.append(count)
            packet += innerPacket
            
            return ControlPacketV2(type: .multiSwitch, payloadArray: packet).getPacket()
        }
        else {
            var packets = [StoneMultiSwitchPacket]()
            for stone in stones {
                let crownstoneId = stone["crownstoneId"]
                let timeout      = NSNumber(value: 0)
                let state        = stone["state"]
                let intent       = NSNumber(value: 4)
                
                
                if (crownstoneId != nil && state != nil) {
                    packets.append(StoneMultiSwitchPacket(crownstoneId: crownstoneId!.uint8Value, state: state!.floatValue, timeout: timeout.uint16Value, intent: intent.uint8Value))
                }
            }
            
            if (packets.count > 0) {
                let meshPayload = MeshMultiSwitchPacket(type: .simpleList, packets: packets).getPacket()
                let commandPayload = ControlPacket(type: .mesh_multiSwitch, payloadArray: meshPayload).getPacket()
                return commandPayload
            }
            return [UInt8]()
        }
    }
    
    /** LEGACY **/
     func getSetupPacket(type: UInt8, crownstoneId: UInt8, adminKey: String, memberKey: String, guestKey: String, meshAccessAddress: String, ibeaconUUID: String, ibeaconMajor: UInt16, ibeaconMinor: UInt16) -> [UInt8] {
        var data : [UInt8] = []
        data.append(type)
        data.append(crownstoneId)
        
        data += Conversion.ascii_or_hex_string_to_16_byte_array(adminKey)
        data += Conversion.ascii_or_hex_string_to_16_byte_array(memberKey)
        data += Conversion.ascii_or_hex_string_to_16_byte_array(guestKey)
        
        data += Conversion.hex_string_to_uint8_array(meshAccessAddress)
        
        data += Conversion.ibeaconUUIDString_to_reversed_uint8_array(ibeaconUUID)
        data += Conversion.uint16_to_uint8_array(ibeaconMajor)
        data += Conversion.uint16_to_uint8_array(ibeaconMinor)
        
        return ControlPacket(type: .setup, payloadArray: data).getPacket()
    }
    
    func getSetupPacketV2(
        crownstoneId: UInt8, sphereId: UInt8,
        adminKey: String, memberKey: String, basicKey: String, localizationKey: String, serviceDataKey: String, meshNetworkKey: String, meshApplicationKey: String, meshDeviceKey: String,
        ibeaconUUID: String, ibeaconMajor: UInt16, ibeaconMinor: UInt16
        ) -> [UInt8] {
        var data : [UInt8] = []
        data.append(crownstoneId)
        data.append(sphereId)
        
        data += Conversion.ascii_or_hex_string_to_16_byte_array(adminKey)
        data += Conversion.ascii_or_hex_string_to_16_byte_array(memberKey)
        data += Conversion.ascii_or_hex_string_to_16_byte_array(basicKey)
        data += Conversion.ascii_or_hex_string_to_16_byte_array(serviceDataKey)
        data += Conversion.ascii_or_hex_string_to_16_byte_array(localizationKey)
        
        data += Conversion.ascii_or_hex_string_to_16_byte_array(meshDeviceKey)
        data += Conversion.ascii_or_hex_string_to_16_byte_array(meshApplicationKey)
        data += Conversion.ascii_or_hex_string_to_16_byte_array(meshNetworkKey)
        
        data += Conversion.ibeaconUUIDString_to_reversed_uint8_array(ibeaconUUID)
        data += Conversion.uint16_to_uint8_array(ibeaconMajor)
        data += Conversion.uint16_to_uint8_array(ibeaconMinor)
        
        
       if controlVersion == .v2 { return ControlPacketV2(type: .setup, payloadArray: data).getPacket()}
       else                     { return ControlPacket(  type: .setup, payloadArray: data).getPacket()}
    }

}

 let ControlPacketsGenerator = ControlPacketsGeneratorClass()
