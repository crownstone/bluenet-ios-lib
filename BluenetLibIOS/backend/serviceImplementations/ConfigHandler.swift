//
//  ConfigHandler.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

open class ConfigHandler {
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
    
    open func setIBeaconUUID(_ uuid: String) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.ibeacon_UUID, payload: uuid)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setPWMPeriod(_ pwmPeriod: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.pwm_PERIOD, payload32: pwmPeriod.uint32Value)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setScanDuration(_ scanDurationsMs: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.scan_DURATION, payload16: scanDurationsMs.uint16Value)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setScanSendDelay(_ scanSendDelay: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.scan_SEND_DELAY, payload16: scanSendDelay.uint16Value)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setScanBreakDuration(_ scanBreakDuration: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.scan_BREAK_DURATION, payload16: scanBreakDuration.uint16Value)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setScanFilter(_ scanFilter: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.scan_BREAK_DURATION, payload8: scanFilter.uint8Value)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setScanFilterFraction(_ scanFilterFraction: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.scan_FILTER_FRACTION, payload16: scanFilterFraction.uint16Value)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    func _writeToConfig(packet: [UInt8]) -> Promise<Void> {
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.ConfigControl,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }

    
    
}
