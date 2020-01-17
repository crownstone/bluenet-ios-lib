//
//  Debug.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 17/01/2020.
//  Copyright © 2020 Alex de Mulder. All rights reserved.
//


import Foundation
import PromiseKit
import CoreBluetooth

public class DebugHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    public func getBehaviourDebugInformation() -> Promise<Dictionary<String,Any>> {
        return Promise<Dictionary<String,Any>> { seal in
            let writeCommand : voidPromiseCallback = {
                return self._writeControlPacket(ControlPacketV2(type: .getBehaviourDebug).getPacket())
            }
            self.bleManager.setupSingleNotification(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.ControlV2, writeCommand: writeCommand)
                .done{ data -> Void in
                    var result = Dictionary<String,Any>()
                    let resultPacket = ResultPacketV2()
                    resultPacket.load(data)
                    if (resultPacket.valid == false) {
                        return seal.reject(BluenetError.INCORRECT_RESPONSE_LENGTH)
                    }
                    
                    result["time"]                = Conversion.uint8_array_to_uint32(Array(data[0..<4]))
                    result["sunrise"]             = Conversion.uint8_array_to_uint32(Array(data[4..<8]))
                    result["sunset"]              = Conversion.uint8_array_to_uint32(Array(data[8..<12]))

                    result["overrideState"]       = data[12]
                    result["behaviourState"]      = data[13]
                    result["aggregatedState"]     = data[14]
                    result["dimmerPowered"]       = data[15]
                    result["behaviourEnabled"]    = data[16]

                    result["activeBehaviours"]    = Conversion.uint8_array_to_uint64(Array(data[17..<25]))
                    result["activeEndConditions"] = Conversion.uint8_array_to_uint64(Array(data[25..<33]))
                    
                    result["presenceProfile_0"]   = Conversion.uint8_array_to_uint64(Array(data[33..<41]))
                    result["presenceProfile_1"]   = Conversion.uint8_array_to_uint64(Array(data[41..<49]))
                    result["presenceProfile_2"]   = Conversion.uint8_array_to_uint64(Array(data[49..<57]))
                    result["presenceProfile_3"]   = Conversion.uint8_array_to_uint64(Array(data[57..<65]))
                    result["presenceProfile_4"]   = Conversion.uint8_array_to_uint64(Array(data[65..<73]))
                    result["presenceProfile_5"]   = Conversion.uint8_array_to_uint64(Array(data[73..<81]))
                    result["presenceProfile_6"]   = Conversion.uint8_array_to_uint64(Array(data[81..<89]))
                    result["presenceProfile_7"]   = Conversion.uint8_array_to_uint64(Array(data[89..<97]))
                    result["presenceProfile_8"]   = Conversion.uint8_array_to_uint64(Array(data[97..<105]))
                    
                    seal.fulfill(result)
                }
                .catch{ err in seal.reject(err) }
        }
    }
    
    
    
    
    
    // MARK: Util

    func _writeControlPacket(_ packet: [UInt8]) -> Promise<Void> {
        if self.bleManager.connectionState.operationMode == .setup {
            return _writeSetupControlPacket(bleManager: self.bleManager, packet)
        }
        else {
            return _writeGenericControlPacket(bleManager: self.bleManager, packet)
        }
    }
    
    
    func _readControlPacket() -> Promise<[UInt8]> {
        if self.bleManager.connectionState.controlVersion == .v2 {
            return self.bleManager.readCharacteristic(
                CSServices.CrownstoneService,
                characteristicId: CrownstoneCharacteristics.ResultV2
            )
        }
        return self.bleManager.readCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.Control
        )
    }
    
}

