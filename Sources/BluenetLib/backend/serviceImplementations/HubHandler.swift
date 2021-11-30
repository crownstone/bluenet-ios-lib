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
    let handle : UUID
    
    init (handle: UUID, bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.handle     = handle
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    public func sendHubData(_ encryptionOption: UInt8, payload: [UInt8], timeoutSeconds: Double = 5, successIfWriteSuccessful: Bool = false ) -> Promise<[UInt8]> {
        return Promise<[UInt8]> { seal in
        let option = EncryptionOption(rawValue: encryptionOption)!
        let packet = ControlPacketsGenerator.getHubDataPacket(encryptionOption: option, payload: payload)
        let readParameters = getControlReadParameters(bleManager: bleManager, handle: self.handle);
        let writeCommand = {() -> Promise<Void> in return _writeControlPacketWithoutWaitingForReply(bleManager: self.bleManager, self.handle, packet) }
        var resultData : [UInt8] = []
        self.bleManager.setupNotificationStream(
            self.handle,
            serviceId: readParameters.service,
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
                            resultData = result.payload
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
            timeout: timeoutSeconds, successIfWriteSuccessful: successIfWriteSuccessful)
            .done{ _ -> Void in
                seal.fulfill(resultData)
            }
            .catch{ err in
                if let bleErr = err as? BluenetError {
                    if (bleErr == BluenetError.NOTIFICATION_STREAM_TIMEOUT) {
                        seal.reject(BluenetError.HUB_REPLY_TIMEOUT)
                    }
                    else {
                        seal.reject(err)
                    }
                }
                else {
                    seal.reject(err)
                }
            }
        }
    }
    
}

