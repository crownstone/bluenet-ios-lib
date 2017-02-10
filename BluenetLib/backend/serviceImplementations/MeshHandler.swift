//
//  MeshHandler.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 03/02/2017.
//  Copyright © 2017 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

open class MeshHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    var deviceList : [String: AvailableDevice]!
    var channelUsage : [MeshChannel: Double]!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings, deviceList: [String: AvailableDevice]) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
        self.deviceList = deviceList
        
        self.channelUsage = [MeshChannel: Double]()
    }
    
    
    /**
     * This allows you to send a keepAliveState message to multiple Crownstones via the Mesh network.
     * The timeout is usually per region, stones are in the format:
     * [ [crownstoneId: Number(UInt16), action: Number(Bool), state: Number(Float: [0 .. 1])] ]
     */
    open func keepAliveState(timeout: UInt16, stones: [[String: NSNumber]]) -> Promise<Void> {
        var packets = [StoneKeepAlivePacket]()
        for stone in stones {
            let crownstoneId = stone["crownstoneId"]
            let action       = stone["action"]
            let state        = stone["state"]
            
            if (crownstoneId != nil && action != nil && state != nil) {
                packets.append( StoneKeepAlivePacket(crownstoneId: crownstoneId!.uint16Value, action: action!.boolValue, state: state!.floatValue ))
            }
        }
        
        if (packets.count > 0) {
            let payload = MeshKeepAlivePacket(timeout: timeout, packets: packets)
            return self._writeToMesh(channel: .KeepAlive, payload: payload.getPacket())
        }
        else {
            return Promise<Void> { fulfill, reject in reject(BleError.NO_KEEPALIVE_STATE_ITEMS)}
        }
    }
    
    
    /**
     * This allows you to send a keepAliveState message to multiple Crownstones via the Mesh network.
     * It will make the Crownstone repeat it's last known mesh message.
     */
    open func keepAlive() -> Promise<Void> {
        let data = MeshControlPacket(channel: .KeepAlive, payload: [UInt8]())
        return self._writeToMesh(channel: .KeepAlive, payload: [UInt8]())
    }
    
    /**
     * Send the same control command to multiple crownstones defined by their ids
     */
    open func batchControlCommand(crownstoneIds: [UInt16], commandPacket: [UInt8]) -> Promise<Void> {
        let payload = MeshCommandPacket(messageType: .control, crownstoneIds: crownstoneIds, payload: commandPacket)
        return self._writeToMesh(channel: .Command, payload: payload.getPacket())
    }
    
    /**
     * Send the same beacon instruction to multiple crownstones defined by their ids
     */
    open func batchBeaconCommand(crownstoneIds: [UInt16], beaconPacket: [UInt8]) -> Promise<Void> {
        let payload = MeshCommandPacket(messageType: .beacon, crownstoneIds: crownstoneIds, payload: beaconPacket)
        return self._writeToMesh(channel: .Command, payload: payload.getPacket())
    }
    
    /**
     * Send the same config command to multiple crownstones defined by their ids
     */
    open func batchConfigCommand(crownstoneIds: [UInt16], configPacket: [UInt8]) -> Promise<Void> {
        let payload = MeshCommandPacket(messageType: .config, crownstoneIds: crownstoneIds, payload: configPacket)
        return self._writeToMesh(channel: .Command, payload: payload.getPacket())
    }
    
    /**
     * Send the same state command to multiple crownstones defined by their ids
     */
    open func batchStateCommand(crownstoneIds: [UInt16], statePacket: [UInt8]) -> Promise<Void> {
        let payload = MeshCommandPacket(messageType: .state, crownstoneIds: crownstoneIds, payload: statePacket)
        return self._writeToMesh(channel: .Command, payload: payload.getPacket())
    }
    
  
    /**
     * This allows you to send a keepAliveState message to multiple Crownstones via the Mesh network.
     * The timeout is usually per region, stones are in the format:
     * [ [crownstoneId: Number(UInt16), timeout: Number(UInt16), state: Number(Float: [0 .. 1])] ]
     */
    open func MultiSwitch(intent: UInt8, stones:[[String: NSNumber]]) -> Promise<Void> {
        var packets = [StoneSwitchPacket]()
        for stone in stones {
            let crownstoneId = stone["crownstoneId"]
            let timeout      = stone["timeout"]
            let state        = stone["state"]
            let intent       = stone["intent"]
            
            if (crownstoneId != nil && timeout != nil && state != nil && intent != nil) {
                packets.append(StoneSwitchPacket(crownstoneId: crownstoneId!.uint16Value, state: state!.floatValue, timeout: timeout!.uint16Value, intent: intent!.uint8Value))
            }
        }
        
        if (packets.count > 0) {
            let payload = MeshSwitchPacket(packets: packets)
            return self._writeToMesh(channel: .MultiSwitch, payload: payload.getPacket())
        }
        else {
            return Promise<Void> { fulfill, reject in reject(BleError.NO_SWITCH_STATE_ITEMS)}
        }
    }
    
    /**
     * Send the same control command to multiple crownstones defined by their ids
     */
    open func meshCommandSetSwitchState(crownstoneIds: [UInt16], state: Float, intent: IntentType) -> Promise<Void> {
        let commandPacket = ControlPacketsGenerator.getSwitchStatePacket(state, intent: intent)
        let payload = MeshCommandPacket(messageType: .control, crownstoneIds: crownstoneIds, payload:commandPacket)
        return self._writeToMesh(channel: .Command, payload: payload.getPacket())
    }
    
    
    func _writeToMesh(channel: MeshChannel, payload: [UInt8]) -> Promise<Void> {
        let now = Date().timeIntervalSince1970
        var dt : Double = 1
        
        // track the time to delay commands to ensure the delivery of messages.
        if (self.channelUsage[channel] != nil) {
            // if there is less than half a second between sending messages on this channel, delay for half a second.
            dt = now - self.channelUsage[channel]!
        }
        self.channelUsage[channel] = Date().timeIntervalSince1970
        
        // delay the mesh message if required to ensure propagation
        return Promise<Void> { fulfill, reject in
            if (timeoutDurations.waitForMeshPropagation - dt > 0) {
                delay(timeoutDurations.waitForMeshPropagation - dt, fulfill)
            }
            else { fulfill() }
        }
        .then{ _ in return self._writeToMesh(channel: channel, payload: payload)}
    }
        
    func _writeToMeshWithoutDelayCheck(channel: MeshChannel, payload: [UInt8]) -> Promise<Void> {
        let packet = MeshControlPacket(channel: channel, payload: payload).getPacket()
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.MeshControl,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
}
