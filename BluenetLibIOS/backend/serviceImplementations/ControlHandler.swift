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

public class ControlHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    var deviceList : [String: AvailableDevice]!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings, deviceList: [String: AvailableDevice]) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
        self.deviceList = deviceList
    }
    
    /**
     * Set the switch state. If 0 or 1, switch on or off. If 0 < x < 1 then dim.
     * TODO: currently only relay is supported.
     */
    public func setSwitchState(state: NSNumber) -> Promise<Void> {
        print ("------ BLUENET_LIB: switching to \(state)")
        let roundedState = max(0, min(255, round(state.doubleValue * 255)))
        let switchState = UInt8(roundedState)
        let packet : [UInt8] = [switchState]
        return self.bleManager.writeToCharacteristic(
            CSServices.PowerService,
            characteristicId: PowerCharacteristics.Relay,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse
        )
    }
    
    /**
     * Set the switch state. If 0 or 1, switch on or off. If 0 < x < 1 then dim.
     * TODO: currently only relay is supported.
     */
    public func setSwitchStateDemo(state: NSNumber) -> Promise<Void> {
        print ("------ BLUENET_LIB: switching to \(state)")
        let roundedState = max(0, min(255, round(state.doubleValue)))
        let switchState = UInt8(roundedState)
        let packet : [UInt8] = [switchState]
        return self.bleManager.writeToCharacteristic(
            CSServices.PowerService,
            characteristicId: PowerCharacteristics.Relay,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse
        )
    }
    
  
    
    public func putInDFU() -> Promise<Void> {
        print ("------ BLUENET_LIB: switching to DFU")
        
        let packet = ControlPacket(type: .GOTO_DFU).getPacket()
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.Control,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse
        )
    }
    
    public func disconnect() -> Promise<Void> {
        print ("------ BLUENET_LIB: REQUESTING IMMEDIATE DISCONNECT")
        
        let packet = ControlPacket(type: .DISCONNECT).getPacket()
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.Control,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse
        )
    }


    
}
