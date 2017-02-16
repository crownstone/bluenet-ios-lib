//
//  DfuHandler.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth


open class DeviceHandler {
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
     * Returns a symvar version number like  "1.1.0"
     */
    open func getFirmwareRevision() -> Promise<String> {
        return self.bleManager.readCharacteristicWithoutEncryption(CSServices.DeviceInformation, characteristic: DeviceCharacteristics.FirmwareRevision)
            .then{ data -> Promise<String> in return Promise<String>{fulfill, reject in fulfill(Conversion.uint8_array_to_string(data)) }}
    }
    
}
