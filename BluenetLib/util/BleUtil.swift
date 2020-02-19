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

func _writeSetupControlPacket(bleManager: BleManager, _ packet: [UInt8]) -> Promise<Void> {
    return bleManager.getCharacteristicsFromDevice(CSServices.SetupService)
        .then{(characteristics) -> Promise<Void> in
            if getCharacteristicFromList(characteristics, SetupCharacteristics.SetupControlV3) != nil {
                return bleManager.writeToCharacteristic(
                    CSServices.SetupService,
                    characteristicId: SetupCharacteristics.SetupControlV3,
                    data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
                    type: CBCharacteristicWriteType.withResponse
                )
            }
            else if getCharacteristicFromList(characteristics, SetupCharacteristics.SetupControlV2) != nil {
                return bleManager.writeToCharacteristic(
                    CSServices.SetupService,
                    characteristicId: SetupCharacteristics.SetupControlV2,
                    data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
                    type: CBCharacteristicWriteType.withResponse
                )
            }
            else if getCharacteristicFromList(characteristics, SetupCharacteristics.SetupControl) != nil {
                return bleManager.writeToCharacteristic(
                    CSServices.SetupService,
                    characteristicId: SetupCharacteristics.SetupControl,
                    data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
                    type: CBCharacteristicWriteType.withResponse
                )
            }
            else {
                return bleManager.writeToCharacteristic(
                    CSServices.SetupService,
                    characteristicId: SetupCharacteristics.Control,
                    data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
                    type: CBCharacteristicWriteType.withResponse
                )
            }
    }
}

func getControlWriteParameters(bleManager: BleManager) -> BleParamaters {
    let service        = CSServices.CrownstoneService;
    var characteristic = CrownstoneCharacteristics.Control

    // determine where to write
    if bleManager.connectionState.controlVersion == .v2 {
        characteristic = CrownstoneCharacteristics.ControlV2
    }

    return BleParamaters(service: service, characteristic: characteristic)
}

func getControlReadParameters(bleManager: BleManager) -> BleParamaters {
    let service        = CSServices.CrownstoneService;
    var characteristic = CrownstoneCharacteristics.Control

    // determine where to get result data from
    if bleManager.connectionState.controlVersion == .v2 {
        characteristic = CrownstoneCharacteristics.ResultV2
    }

    return BleParamaters(service: service, characteristic: characteristic)
}
  

func _writeGenericControlPacket(bleManager: BleManager, _ packet: [UInt8]) -> Promise<Void> {
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

func getConfigPayloadFromResultPacket<T>(_ bleManager: BleManager, _ resultPacket: ResultBasePacket) throws -> T {
    if bleManager.connectionState.controlVersion == .v2 {
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

func getControlPayloadFromResultPacket<T>(_ bleManager: BleManager, _ resultPacket: ResultBasePacket) throws -> T {
    if bleManager.connectionState.controlVersion == .v2 {
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
    var controlMode: ControlVersionType
    var operationMode: CrownstoneMode
}

func _getCrownstoneModeInformation(bleManager: BleManager) -> Promise<ModeInformation> {
    return bleManager.getServicesFromDevice()
        .then{ services -> Promise<ModeInformation> in
            return Promise<ModeInformation> { seal in
                if getServiceFromList(services, CSServices.SetupService) != nil {
                    _ = bleManager.getCharacteristicsFromDevice(CSServices.SetupService)
                        .done{(characteristics : [CBCharacteristic]) -> Void in
                            if getCharacteristicFromList(characteristics, SetupCharacteristics.SetupControlV3) != nil {
                                seal.fulfill(ModeInformation(controlMode: .v2, operationMode: .setup))
                            }
                            else {
                                // all the other control characteristics use control v1
                                seal.fulfill(ModeInformation(controlMode: .v1, operationMode: .setup))
                            }
                        }
                }
                else if getServiceFromList(services, CSServices.CrownstoneService) != nil {
                    _ = bleManager.getCharacteristicsFromDevice(CSServices.CrownstoneService)
                       .done{(characteristics : [CBCharacteristic]) -> Void in
                           if getCharacteristicFromList(characteristics, CrownstoneCharacteristics.ControlV2) != nil {
                               seal.fulfill(ModeInformation(controlMode: .v2, operationMode: .operation))
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
