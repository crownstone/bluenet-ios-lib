//
//  broadcast.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 04/12/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

public class BroadcastHandler {
    let peripheralStateManager : PeripheralStateManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    
    
    init (peripheralStateManager: PeripheralStateManager, eventBus: EventBus, settings: BluenetSettings) {
        self.peripheralStateManager = peripheralStateManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    

    
    
    public func multiSwitch(referenceId: String, stoneId: UInt8, switchState: UInt8, autoExecute: Bool = true) -> Promise<Void> {
        return Promise<Void> { seal in
            
            let switchState = min(100, switchState)
            let packet  = BroadcastStone_SwitchPacket(crownstoneId: stoneId, state: switchState).getPacket()
            let element = BroadcastElement(referenceId: referenceId, type: .multiSwitch, packet: packet, seal: seal, target: stoneId)
            
            self.peripheralStateManager.loadElement(element: element, autoExecute: autoExecute)
        }
    }
    
    
    public func turnOn(referenceId: String, stoneId: UInt8, autoExecute: Bool = true) -> Promise<Void> {
        return Promise<Void> { seal in
            
            let switchState : UInt8 = 255
            let packet  = BroadcastStone_SwitchPacket(crownstoneId: stoneId, state: switchState).getPacket()
            let element = BroadcastElement(referenceId: referenceId, type: .multiSwitch, packet: packet, seal: seal, target: stoneId)
            
            self.peripheralStateManager.loadElement(element: element, autoExecute: autoExecute)
        }
    }
    
    
    public func execute() {
        self.peripheralStateManager.broadcastCommand()
    }
    
    public func setBehaviourSettings(referenceId: String, enabled: Bool) -> Promise<Void> {
       return Promise<Void> { seal in

           var enabledState : UInt32 = 0
           if (enabled) {
              enabledState = 1
           }
        
           let element = BroadcastElement(referenceId: referenceId, type: .behaviourSettings, packet: Conversion.uint32_to_uint8_array(enabledState), seal: seal, singular: true, duration: 5)
           
           self.peripheralStateManager.loadElement(element: element)
       }
    }

    
    /**
     * Method for setting the time on a crownstone
     */
    public func setTime(referenceId: String, time: UInt32? = nil, sunriseSecondsSinceMidnight: UInt32, sunsetSecondsSinceMidnight: UInt32) -> Promise<Void> {
        return Promise<Void> { seal in
            
            var packet : [UInt8]!
            if let customTime = time {
                packet = Broadcast_SetTimePacket(time: customTime, sunrisetSecondsSinceMidnight: sunriseSecondsSinceMidnight, sunsetSecondsSinceMidnight: sunsetSecondsSinceMidnight).getPacket()
            }
            else {
                packet = Broadcast_SetTimePacket(sunrisetSecondsSinceMidnight: sunriseSecondsSinceMidnight, sunsetSecondsSinceMidnight: sunsetSecondsSinceMidnight).getPacket()
            }
            
            
            let element = BroadcastElement(
                referenceId: referenceId,
                type: .timeData,
                packet: packet,
                seal: seal,
                singular: true
            )
            
            self.peripheralStateManager.loadElement(element: element)
        }
    }
    
    
    public func updateTrackedDevice(
        referenceId: String,
        trackingNumber: UInt16,
        locationUid: UInt8,
        profileId: UInt8,
        rssiOffset: UInt8,
        ignoreForPresence: Bool,
        tapToToggle: Bool,
        deviceToken: UInt32,
        ttlMinutes: UInt16
        ) -> Promise<Void> {
        return Promise<Void> { seal in
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
            let element = BroadcastElement(
                referenceId: referenceId,
                type: .updateTrackedDevice,
                packet: payload,
                seal: seal,
                singular: true
            )
            
            self.peripheralStateManager.loadElement(element: element)
        }
    }
    
    
    
    
    
}
