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
        let packet = data.getPacket();
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.ConfigControl,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    open func setPWMPeriod(_ pwmPeriod: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.pwm_PERIOD, payload32: pwmPeriod.uint32Value)
        let packet = data.getPacket();
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.ConfigControl,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }

    
    
}
