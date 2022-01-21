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
        let loggingToken = UUID().uuidString
        
        LOG.info("BluenetBroadcast: Loading multiswitch referenceId:\(referenceId) stoneId:\(stoneId) switchState:\(switchState) autoExecute:\(autoExecute) loggingToken:\(loggingToken)")
        return Promise<Void> { seal in
            
            let switchState = min(100, switchState)
            let packet  = BroadcastStone_SwitchPacket(crownstoneId: stoneId, state: switchState).getPacket()
            let element = BroadcastElement(referenceId: referenceId, type: .multiSwitch, packet: packet, seal: seal, target: stoneId)
            element.loggingToken = loggingToken
            
            self.peripheralStateManager.loadElement(element: element, autoExecute: autoExecute)
        }
    }
    
    
    public func turnOn(referenceId: String, stoneId: UInt8, autoExecute: Bool = true) -> Promise<Void> {
        let loggingToken = UUID().uuidString
        
        LOG.info("BluenetBroadcast: Loading turnOn referenceId:\(referenceId) stoneId:\(stoneId) autoExecute:\(autoExecute) loggingToken:\(loggingToken)")
        return Promise<Void> { seal in
            
            let switchState : UInt8 = 255
            let packet  = BroadcastStone_SwitchPacket(crownstoneId: stoneId, state: switchState).getPacket()
            let element = BroadcastElement(referenceId: referenceId, type: .multiSwitch, packet: packet, seal: seal, target: stoneId)
            element.loggingToken = loggingToken
            
            self.peripheralStateManager.loadElement(element: element, autoExecute: autoExecute)
        }
    }
    
    
    public func execute() {
        LOG.info("BluenetBroadcast: executing broadcast")
        self.peripheralStateManager.broadcastCommand()
    }
    
    public func setBehaviourSettings(referenceId: String, enabled: Bool) -> Promise<Void> {
        let loggingToken = UUID().uuidString
        LOG.info("BluenetBroadcast: Loading setBehaviourSettings referenceId:\(referenceId) enabled:\(enabled) loggingToken:\(loggingToken)")
       return Promise<Void> { seal in

           var enabledState : UInt32 = 0
           if (enabled) {
              enabledState = 1
           }
        
           let element = BroadcastElement(referenceId: referenceId, type: .behaviourSettings, packet: Conversion.uint32_to_uint8_array(enabledState), seal: seal, singular: true, duration: 5)
           element.loggingToken = loggingToken
           
           self.peripheralStateManager.loadElement(element: element)
       }
    }

    
    /**
     * Method for setting the time on a crownstone
     */
    public func setTime(referenceId: String, time: UInt32? = nil, sunriseSecondsSinceMidnight: UInt32, sunsetSecondsSinceMidnight: UInt32, customValidationNonce: UInt32? = nil) -> Promise<Void> {
        let loggingToken = UUID().uuidString
        LOG.info("BluenetBroadcast: Loading setTime referenceId:\(referenceId) time:\(time) sunriseSecondsSinceMidnight:\(sunriseSecondsSinceMidnight) sunsetSecondsSinceMidnight:\(sunsetSecondsSinceMidnight) customValidationNonce:\(customValidationNonce) loggingToken:\(loggingToken)")
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
                singular: true,
                customValidationNonce: customValidationNonce
            )
            element.loggingToken = loggingToken
            
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
        let loggingToken = UUID().uuidString
        LOG.info("BluenetBroadcast: Loading updateTrackedDevice referenceId:\(referenceId) trackingNumber:\(trackingNumber) locationUid:\(locationUid) deviceToken:\(deviceToken) ignoreForPresence:\(ignoreForPresence) loggingToken:\(loggingToken)")
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
            element.loggingToken = loggingToken
            
            self.peripheralStateManager.loadElement(element: element)
        }
    }
    
    
    
    
    
}
