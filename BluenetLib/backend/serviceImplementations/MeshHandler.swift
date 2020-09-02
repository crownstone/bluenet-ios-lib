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
        switch (self.bleManager.connectionState.connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2, .v3:
                 meshPayload = MeshCommandPacket(type: .control, crownstoneIds: [], payload: commandPayload).getPacket()
            case .v5:
                 meshPayload = MeshCommandPacketV5(type: .control, payload: commandPayload).getPacket()
        }
        
        let packet = ControlPacketsGenerator.getMeshCommandPacket(commandPacket: meshPayload)
        return _writeControlPacket(bleManager: self.bleManager, packet)
    }
    
    public func sendNoOp( ) -> Promise<Void> {
        let commandPayload = ControlPacketsGenerator.getNoOpPacket()
        var meshPayload : [UInt8]
        switch (self.bleManager.connectionState.connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2, .v3:
                 meshPayload = MeshCommandPacket(type: .control, crownstoneIds: [], payload: commandPayload).getPacket()
            case .v5:
                 meshPayload = MeshCommandPacketV5(type: .control, payload: commandPayload).getPacket()
        }
      
        let packet = ControlPacketsGenerator.getMeshCommandPacket(commandPacket: meshPayload)
        return _writeControlPacket(bleManager: self.bleManager, packet)
    }

}

