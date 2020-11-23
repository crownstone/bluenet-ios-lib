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


public enum HubDataTypes : UInt8 {
    case setup = 0
}

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
        let readParameters = getControlReadParameters(bleManager: bleManager);
        let writeCommand = {() -> Promise<Void> in return _writeControlPacket(bleManager: self.bleManager, packet) }
        return self.bleManager.setupNotificationStream(
            readParameters.service,
            characteristicId: readParameters.characteristic,
            writeCommand: writeCommand,
            resultHandler: {(returnData) -> ProcessType in
                if let data = returnData as? [UInt8] {
                    let result = StatePacketsGenerator.getReturnPacket()
                    result.load(data)
                    if (result.valid) {
                        if (result.resultCode == ResultValue.WAIT_FOR_SUCCESS) {
                            return .CONTINUE
                        }
                        else if (result.resultCode == ResultValue.SUCCESS) {
                            return .FINISHED
                        }
                        else {
                            return .ABORT_ERROR
                        }
                    }
                    else {
                        // stop, something went wrong
                        return .ABORT_ERROR
                    }
                }
                else {
                    // stop, something went wrong
                    return .ABORT_ERROR
                }
            },
            timeout: 5, successIfWriteSuccessful: true)
    }
    
    public func transferTokenAndSphereId(hubToken: String, sphereId: String) -> Promise<Void> {
        var payload : [UInt8] = []
        let hubTokenBytes = Conversion.string_to_uint8_array(hubToken)
        let sphereIdBytes = Conversion.string_to_uint8_array(sphereId)
        
        payload.append(HubDataTypes.setup.rawValue)
        payload += Conversion.uint16_to_uint8_array(NSNumber(value: hubTokenBytes.count).uint16Value)
        payload += hubTokenBytes
        payload += Conversion.uint16_to_uint8_array(NSNumber(value: sphereIdBytes.count).uint16Value)
        payload += sphereIdBytes
        
        return self.sendHubData(EncryptionOption.noEncryption.rawValue, payload: payload)
    }

}

