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
    var connectionProtocolVersion : ConnectionProtocolVersion = .v1
    
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
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                return FactoryResetPacket().getPacket()
            case .v3:
                return FactoryResetPacketV3().getPacket()
            case .v5:
                return FactoryResetPacketV5().getPacket()
        }
    }
    
     func getSwitchStatePacket(_ state: Float) -> [UInt8] {
        let switchState = min(1,max(0,state))*100
        let value = NSNumber(value: switchState as Float).uint8Value
        return self.getControlPacket(type: ControlType.switch).load(value).getPacket()
    }
    
     func getResetPacket() -> [UInt8] {
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                return ControlPacket(  type: .reset).getPacket()
            case .v3:
                return ControlPacketV3(type: .reset).getPacket()
            case .v5:
                return ControlPacketV5(type: .reset).getPacket()
        }
    }
    
     func getPutInDFUPacket() -> [UInt8] {
        return self.getControlPacket(type: ControlType.goto_DFU).getPacket()
    }
    
     func getDisconnectPacket() -> [UInt8] {
        return self.getControlPacket(type: ControlType.disconnect).getPacket()
    }
    
     func getRelaySwitchPacket(_ state: UInt8) -> [UInt8] {
        return self.getControlPacket(type: ControlType.relay).load(state).getPacket()
    }
    
     func getPwmSwitchPacket(_ state: Float) -> [UInt8] {
        let switchState : UInt8 = NSNumber(value: min(1,max(0,state))*100).uint8Value
        return self.getControlPacket(type: ControlType.pwm).load(switchState).getPacket()
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
        return self.getControlPacket(type: ControlType.reset_ERRORS).load(errorMask).getPacket()
    }
    
     func getSetTimePacket(_ time: UInt32) -> [UInt8] {
        return self.getControlPacket(type: ControlType.set_TIME).load(time).getPacket()
    }
    
     func getNoOpPacket() -> [UInt8] {
        return self.getControlPacket(type: ControlType.no_OPERATION).getPacket()
    }
    
     func getAllowDimmingPacket(_ allow: Bool) -> [UInt8] {
        var allowValue : UInt8 = 0
        if (allow) {
            allowValue = 1
        }
        return self.getControlPacket(type: ControlType.allow_dimming).load(allowValue).getPacket()
    }
    
     func getLockSwitchPacket(_ lock: Bool) -> [UInt8] {
        var lockValue : UInt8 = 0
        if (lock) {
            lockValue = 1
        }
        return self.getControlPacket(type: ControlType.lock_switch).load(lockValue).getPacket()
    }
    
     func getSwitchCraftPacket(_ enabled: Bool) -> [UInt8] {
        var enabledValue : UInt8 = 0
        if (enabled) {
            enabledValue = 1
        }
        
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                return ControlPacket(  type: .enable_switchcraft, payload8: enabledValue).getPacket()
            case .v3, .v5:
                let packet = StatePacketsGenerator.getWritePacket(type: .SWITCHCRAFT_ENABLED)
                return packet.load(enabledValue).getPacket()
        }
    }
    
    func getMeshCommandPacket(commandPacket: [UInt8]) -> [UInt8] {
        return self.getControlPacket(type: ControlType.mesh_command).load(commandPacket).getPacket()
    }
    
    
    
    
    func getTurnOnPacket(stones:[[String: NSNumber]]) -> [UInt8] {
        switch (connectionProtocolVersion) {
           case .unknown, .legacy, .v1, .v2:
               return ControlPacketsGenerator.getMultiSwitchPacket(stones: stones)
           case .v3, .v5:
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
               
               var dataArray = [UInt8]()
               dataArray.append(count)
               dataArray += innerPacket
               
               return self.getControlPacket(type: ControlTypeV3.multiSwitch).load(dataArray).getPacket()
       }
    }
    
    func getMultiSwitchPacket(stones:[[String: NSNumber]]) -> [UInt8] {
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
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
            case .v3, .v5:
                var innerPacket = [UInt8]()
                var count : UInt8 = 0
                for stone in stones {
                    let crownstoneId = stone["crownstoneId"]
                    let state        = stone["state"]
                    
                    if (crownstoneId != nil && state != nil) {
                        innerPacket.append(crownstoneId!.uint8Value)
                        innerPacket.append(NSNumber(value: min(1,max(0,state!.floatValue))*100).uint8Value)
                        count += 1
                    }
                }
                
                var dataArray = [UInt8]()
                dataArray.append(count)
                dataArray += innerPacket
                
                return self.getControlPacket(type: ControlTypeV3.multiSwitch).load(dataArray).getPacket()
        }
    }
    
    
    func getTrackedDeviceHeartbeatPacket(
        trackingNumber: UInt16,
        locationUid:    UInt8,
        deviceToken:    UInt32,
        ttlMinutes:     UInt8) -> [UInt8] {
       
        var payload : [UInt8] = []
            
        payload += Conversion.uint16_to_uint8_array(trackingNumber)
        payload.append(locationUid)
        
        let token = Conversion.uint32_to_uint8_array(deviceToken)
        payload.append(token[0])
        payload.append(token[1])
        payload.append(token[2])
        
        payload.append(ttlMinutes)
        
        return self.getControlPacket(type: .trackedDeviceHeartbeat).load(payload).getPacket()
    }
    
    func getTrackedDeviceRegistrationPacket(
        trackingNumber: UInt16,
        locationUid:    UInt8,
        profileId:      UInt8,
        rssiOffset:     UInt8,
        ignoreForPresence: Bool,
        tapToToggle:    Bool,
        deviceToken:    UInt32,
        ttlMinutes:    UInt16) -> [UInt8] {
       
        let payload = ControlPacketsGenerator.getTrackedDeviceRegistrationPayload(
            trackingNumber: trackingNumber,
            locationUid:    locationUid,
            profileId:      profileId,
            rssiOffset:     rssiOffset,
            ignoreForPresence: ignoreForPresence,
            tapToToggle:    tapToToggle,
            deviceToken:    deviceToken,
            ttlMinutes:     ttlMinutes
        )
        
        return self.getControlPacket(type: .registerTrackedDevice).load(payload).getPacket()
    }
    
    func getTrackedDeviceRegistrationPayload(
        trackingNumber: UInt16,
        locationUid:    UInt8,
        profileId:      UInt8,
        rssiOffset:     UInt8,
        ignoreForPresence: Bool,
        tapToToggle:    Bool,
        deviceToken:    UInt32,
        ttlMinutes:    UInt16) -> [UInt8] {
        var data : [UInt8] = []
        
        data += Conversion.uint16_to_uint8_array(trackingNumber)
        data.append(locationUid)
        data.append(profileId)
        data.append(rssiOffset)
        
        var flags : UInt8 = 0
        if (ignoreForPresence) { flags += 1 << 1 }
        if (tapToToggle)       { flags += 1 << 2 }
        
        data.append(flags)
    
        let token = Conversion.uint32_to_uint8_array(deviceToken)
        data.append(token[0])
        data.append(token[1])
        data.append(token[2])
        
        data += Conversion.uint16_to_uint8_array(ttlMinutes)
        
        return data
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
    
    func getSetupPacketV3(
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
        
        
        return self.getControlPacket(type: ControlTypeV3.setup).load(data).getPacket()
    }
    
    /**
     Only for newer protocols.
     */
    func getControlPacket(type: ControlTypeV3) -> BLEPacketBase {
        switch (connectionProtocolVersion) {
            case .v3:
                 return ControlPacketV3(type: type)
            default:
                return ControlPacketV5(type: type)
        }
    }
    func getControlPacket(type: ControlType) -> BLEPacketBase {
        let mappedType = mapControlType_toV3(type: type)
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                return ControlPacket(type:   type)
            case .v3:
                return ControlPacketV3(type: mappedType)
            case .v5:
                return ControlPacketV5(type: mappedType)
        }
    }
    
}

    



 let ControlPacketsGenerator = ControlPacketsGeneratorClass()
