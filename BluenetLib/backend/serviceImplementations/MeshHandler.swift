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

public class MeshHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    var disconnectCommandTimeList : [String: Double]!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    /**
     * This allows you to send a keepAliveState message to multiple Crownstones via the Mesh network.
     * It will make the Crownstone repeat it's last known mesh message.
     */
    public func keepAliveRepeat() -> Promise<Void> {
        let packet = ControlPacket(type: .mesh_keepAliveRepeat).getPacket()
        return _writeControlPacket(bleManager: self.bleManager, packet)
    }
    
    /**
     * This allows you to send a keepAliveState message to multiple Crownstones via the Mesh network.
     * The timeout is usually per region, stones are in the format:
     * [ [crownstoneId: Number(UInt16), action: Number(Bool), state: Number(Float: [0 .. 1])] ]
     */
    public func keepAliveState(timeout: UInt16, stones: [[String: NSNumber]]) -> Promise<Void> {
        var packets = [StoneKeepAlivePacket]()
        for stone in stones {
            let crownstoneId = stone["crownstoneId"]
            let action       = stone["action"]
            let state        = stone["state"]
            
            if (crownstoneId != nil && action != nil && state != nil) {
                packets.append( StoneKeepAlivePacket(crownstoneId: crownstoneId!.uint8Value, action: action!.boolValue, state: state!.floatValue ))
            }
        }
        
        if (packets.count > 0) {
            let meshPayload = MeshKeepAlivePacket(type: .sharedTimeout, timeout: timeout, packets: packets).getPacket()
            let commandPayload = ControlPacket(type: .mesh_keepAliveState, payloadArray: meshPayload).getPacket()
            return _writeControlPacket(bleManager: self.bleManager, commandPayload)
        }
        else {
            return Promise<Void> { seal in seal.reject(BluenetError.NO_KEEPALIVE_STATE_ITEMS)}
        }
    }
    
    
    /**
     * This channel is used to send different switch commands with individual timeouts, switch states and intents to different crownstones in one message
     */
    public func turnOn(stones:[[String: NSNumber]]) -> Promise<Void> {
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getTurnOnPacket(stones: stones))
    }
    
    /**
     * This channel is used to send different switch commands with individual timeouts, switch states and intents to different crownstones in one message
     */
    public func multiSwitch(stones:[[String: NSNumber]]) -> Promise<Void> {
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getMultiSwitchPacket(stones: stones))
    }

    
    public func setTime( time: UInt32 ) -> Promise<Void> {
        let commandPayload = ControlPacketsGenerator.getSetTimePacket(time)

        var meshPayload : [UInt8]
        if self.bleManager.connectionState.connectionProtocolVersion == .v5 {
            meshPayload = MeshCommandPacketV5(type: .control, payload: commandPayload).getPacket()
        }
        else {
            meshPayload = MeshCommandPacket(type: .control, crownstoneIds: [], payload: commandPayload).getPacket()
        }
        
        let packet = ControlPacketsGenerator.getMeshCommandPacket(commandPacket: meshPayload)
        return _writeControlPacket(bleManager: self.bleManager, packet)
    }
    
    public func sendNoOp( ) -> Promise<Void> {
        let commandPayload = ControlPacketsGenerator.getNoOpPacket()
        var meshPayload : [UInt8]
        if self.bleManager.connectionState.connectionProtocolVersion == .v5 {
            meshPayload = MeshCommandPacketV5(type: .control, payload: commandPayload).getPacket()
        }
        else {
            meshPayload = MeshCommandPacket(type: .control, crownstoneIds: [], payload: commandPayload).getPacket()
        }
      
        let packet = ControlPacketsGenerator.getMeshCommandPacket(commandPacket: meshPayload)
        return _writeControlPacket(bleManager: self.bleManager, packet)
    }

}

