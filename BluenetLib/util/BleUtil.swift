//
//  BleUtil.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 24/06/2019.
//  Copyright © 2019 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth
import PromiseKit

func getSessionNonceReadParameters(bleManager: BleManager) -> BleParameters {
    var service : String

    // determine where to write
    var characteristic : String
    if bleManager.connectionState.operationMode == .setup {
        service = CSServices.SetupService
        switch (bleManager.connectionState.connectionProtocolVersion) {
            case  .unknown, .legacy, .v1, .v2, .v3:
                characteristic = SetupCharacteristics.SessionNonce
            case .v5:
                characteristic = SetupCharacteristics.SessionNonceV5
        }
    }
    else {
        service = CSServices.CrownstoneService
        switch (bleManager.connectionState.connectionProtocolVersion) {
            case  .unknown, .legacy, .v1, .v2, .v3:
                characteristic = CrownstoneCharacteristics.SessionNonce
            case .v5:
                characteristic = CrownstoneCharacteristics.SessionNonceV5
        }
    }
    

    return BleParameters(service: service, characteristic: characteristic)
}

func getControlWriteParameters(bleManager: BleManager) -> BleParameters {
    // determine where to write
    var service        : String
    var characteristic : String

    if bleManager.connectionState.operationMode == .setup {
        service = CSServices.SetupService
        switch (bleManager.connectionState.connectionProtocolVersion) {
            case .unknown, .legacy:
                characteristic = SetupCharacteristics.Control
            case .v1:
                characteristic = SetupCharacteristics.SetupControl
            case .v2:
                characteristic = SetupCharacteristics.SetupControlV2
            case .v3:
                characteristic = SetupCharacteristics.SetupControlV3
            case .v5:
                characteristic = SetupCharacteristics.SetupControlV5
        }
    }
    else {
        // we do not check dfu here, we assume just setup en operation mode
        service = CSServices.CrownstoneService
        switch (bleManager.connectionState.connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                characteristic = CrownstoneCharacteristics.Control
            case .v3:
                characteristic = CrownstoneCharacteristics.ControlV3
            case .v5:
                characteristic = CrownstoneCharacteristics.ControlV5
        }
    }

    return BleParameters(service: service, characteristic: characteristic)
}

func getControlReadParameters(bleManager: BleManager) -> BleParameters {
    var service        : String
    var characteristic : String
    // determine where to get result data from
    
    if bleManager.connectionState.operationMode == .setup {
        service = CSServices.SetupService
        switch (bleManager.connectionState.connectionProtocolVersion) {
            case .unknown, .legacy:
                characteristic = SetupCharacteristics.Control
            case .v1:
                characteristic = SetupCharacteristics.SetupControl
            case .v2:
                characteristic = SetupCharacteristics.SetupControlV2
            case .v3:
                characteristic = SetupCharacteristics.ResultV3
            case .v5:
                characteristic = SetupCharacteristics.ResultV5
        }
    }
    else {
        // we do not check dfu here, we assume just setup en operation mode
        service = CSServices.CrownstoneService
        switch (bleManager.connectionState.connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                characteristic = CrownstoneCharacteristics.Control
            case .v3:
                characteristic = CrownstoneCharacteristics.ResultV3
            case .v5:
                characteristic = CrownstoneCharacteristics.ResultV5
        }
    }
    

    return BleParameters(service: service, characteristic: characteristic)
}
  

func _writeControlPacket(bleManager: BleManager, _ packet: [UInt8]) -> Promise<Void> {
    let writeParams = getControlWriteParameters(bleManager: bleManager)
    
    return bleManager.writeToCharacteristic(
        writeParams.service,
        characteristicId: writeParams.characteristic,
        data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
        type: CBCharacteristicWriteType.withResponse
    )
}


func _writePacketWithReply(bleManager: BleManager, service: String, readCharacteristic: String, writeCommand : @escaping voidPromiseCallback) -> Promise<ResultBasePacket> {
    return Promise<ResultBasePacket> { seal in
        bleManager.setupSingleNotification(service, characteristicId: readCharacteristic, writeCommand: writeCommand)
            .done{ data -> Void in
                let resultPacket = StatePacketsGenerator.getReturnPacket()
                resultPacket.load(data)
                if (resultPacket.valid == false) {
                    LOG.error("BluenetLib: Error Invalid response data \(data)")
                    return seal.reject(BluenetError.INCORRECT_RESPONSE_LENGTH)
                }
                seal.fulfill(resultPacket)
            }
            .catch{ err in seal.reject(err) }
    }
}


func _writePacketWithReply(bleManager: BleManager, writeCommand : @escaping voidPromiseCallback) -> Promise<ResultBasePacket> {
    let readParameters = getControlReadParameters(bleManager: bleManager);
    return Promise<ResultBasePacket> { seal in
        bleManager.setupSingleNotification(readParameters.service, characteristicId: readParameters.characteristic, writeCommand: writeCommand)
            .done{ data -> Void in
                let resultPacket = StatePacketsGenerator.getReturnPacket()
                resultPacket.load(data)
                if (resultPacket.valid == false) {
                    LOG.error("BluenetLib: Error Invalid response data \(data)")
                    return seal.reject(BluenetError.INCORRECT_RESPONSE_LENGTH)
                }
                seal.fulfill(resultPacket)
            }
            .catch{ err in seal.reject(err) }
    }
}

func getConfigPayloadFromResultPacket<T>(_ bleManager: BleManager, _ resultPacket: ResultBasePacket) throws -> T {
    var resultPayload : [UInt8]
    
    switch (bleManager.connectionState.connectionProtocolVersion) {
        case .unknown, .legacy, .v1, .v2:
            resultPayload = resultPacket.payload
        case .v3:
            let packetSize = resultPacket.payload.count
            resultPayload = Array(resultPacket.payload[4...packetSize-1]) // 4 is the 2 stateType and 2 ID, rest is data payload
        case .v5:
             let packetSize = resultPacket.payload.count
             resultPayload = Array(resultPacket.payload[6...packetSize-1]) // 6 is the 2 stateType and 2 ID and 2 persistence, rest is data payload
    }
    
    let result : T = try Convert(resultPayload)
    return result
}

func getControlPayloadFromResultPacket<T>(_ bleManager: BleManager, _ resultPacket: ResultBasePacket) throws -> T {
    if bleManager.connectionState.connectionProtocolVersion == .v3 {
        let packetSize = resultPacket.payload.count
        let resultPayload = Array(resultPacket.payload[4...packetSize-1]) // 4 is the 2 stateType and 2 ID, rest is data payload
        let result : T = try Convert(resultPayload)
        return result
    }
    else {
        let result : T = try Convert(resultPacket.payload)
        return result
    }
}

struct ModeInformation {
    var controlMode: ConnectionProtocolVersion
    var operationMode: CrownstoneMode
}

func _getCrownstoneModeInformation(bleManager: BleManager) -> Promise<ModeInformation> {
    return bleManager.getServicesFromDevice()
        .then{ services -> Promise<ModeInformation> in
            return Promise<ModeInformation> { seal in
                if getServiceFromList(services, CSServices.SetupService) != nil {
                    _ = bleManager.getCharacteristicsFromDevice(CSServices.SetupService)
                        .done{(characteristics : [CBCharacteristic]) -> Void in
                            if getCharacteristicFromList(characteristics, SetupCharacteristics.SetupControlV5) != nil {
                                seal.fulfill(ModeInformation(controlMode: .v5, operationMode: .setup))
                            }
                            if getCharacteristicFromList(characteristics, SetupCharacteristics.SetupControlV3) != nil {
                                seal.fulfill(ModeInformation(controlMode: .v3, operationMode: .setup))
                            }
                            else if getCharacteristicFromList(characteristics, SetupCharacteristics.SetupControlV2) != nil {
                                seal.fulfill(ModeInformation(controlMode: .v2, operationMode: .setup))
                            }
                            else if getCharacteristicFromList(characteristics, SetupCharacteristics.SetupControl) != nil {
                                seal.fulfill(ModeInformation(controlMode: .v1, operationMode: .setup))
                            }
                            else {
                                seal.fulfill(ModeInformation(controlMode: .legacy, operationMode: .setup))
                            }
                        }
                }
                else if getServiceFromList(services, CSServices.CrownstoneService) != nil {
                    _ = bleManager.getCharacteristicsFromDevice(CSServices.CrownstoneService)
                       .done{(characteristics : [CBCharacteristic]) -> Void in
                            if getCharacteristicFromList(characteristics, CrownstoneCharacteristics.ControlV5) != nil {
                                seal.fulfill(ModeInformation(controlMode: .v5, operationMode: .operation))
                            }
                            else if getCharacteristicFromList(characteristics, CrownstoneCharacteristics.ControlV3) != nil {
                                seal.fulfill(ModeInformation(controlMode: .v3, operationMode: .operation))
                            }
                            else {
                                seal.fulfill(ModeInformation(controlMode: .v1, operationMode: .operation))
                            }
                       }
                    
                }
                else if getServiceFromList(services, DFUServices.DFU.uuidString) != nil || getServiceFromList(services, DFUServices.SecureDFU.uuidString) != nil {
                    seal.fulfill(ModeInformation(controlMode: .unknown, operationMode: .dfu))
                }
                else {
                    seal.fulfill(ModeInformation(controlMode: .unknown, operationMode: .unknown))
                }
            }
        }
}
