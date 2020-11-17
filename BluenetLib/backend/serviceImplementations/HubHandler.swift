//
//  HubHandler.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 17/11/2020.
//  Copyright © 2020 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth


public class HubHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    public func sendHubData(_ encryptionOption: UInt8, payload: [UInt8] ) -> Promise<Void> {
        let option = EncryptionOption(rawValue: encryptionOption)!
        let packet = ControlPacketsGenerator.getHubDataPacket(encryptionOption: option, payload: payload)
        return _writeControlPacket(bleManager: self.bleManager, packet)
    }

}

