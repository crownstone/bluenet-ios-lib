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
            self.bleManager.setupSingleNotification(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.ResultV2, writeCommand: writeCommand)
                .done{ data -> Void in
                    var result = Dictionary<String,Any>()
                    let resultPacket = ResultPacketV2()
                    resultPacket.load(data)
                    if (resultPacket.valid == false) {
                        return seal.reject(BluenetError.INCORRECT_RESPONSE_LENGTH)
                    }
                    
                    let payload = resultPacket.payload
                    
                    result["time"]                = Conversion.uint8_array_to_uint32(Array(payload[0..<4]))
                    result["sunrise"]             = Conversion.uint8_array_to_uint32(Array(payload[4..<8]))
                    result["sunset"]              = Conversion.uint8_array_to_uint32(Array(payload[8..<12]))

                    result["overrideState"]       = payload[12]
                    result["behaviourState"]      = payload[13]
                    result["aggregatedState"]     = payload[14]
                    result["dimmerPowered"]       = payload[15]
                    result["behaviourEnabled"]    = payload[16]

                    result["activeBehaviours"]    = Conversion.uint64_to_bit_array(Conversion.uint8_array_to_uint64(Array(payload[17..<25])))
                    result["activeEndConditions"] = Conversion.uint64_to_bit_array(Conversion.uint8_array_to_uint64(Array(payload[25..<33])))
                    
                    result["presenceProfile_0"]   = Conversion.uint64_to_bit_array(Conversion.uint8_array_to_uint64(Array(payload[33..<41])))
                    result["presenceProfile_1"]   = Conversion.uint64_to_bit_array(Conversion.uint8_array_to_uint64(Array(payload[41..<49])))
                    result["presenceProfile_2"]   = Conversion.uint64_to_bit_array(Conversion.uint8_array_to_uint64(Array(payload[49..<57])))
                    result["presenceProfile_3"]   = Conversion.uint64_to_bit_array(Conversion.uint8_array_to_uint64(Array(payload[57..<65])))
                    result["presenceProfile_4"]   = Conversion.uint64_to_bit_array(Conversion.uint8_array_to_uint64(Array(payload[65..<73])))
                    result["presenceProfile_5"]   = Conversion.uint64_to_bit_array(Conversion.uint8_array_to_uint64(Array(payload[73..<81])))
                    result["presenceProfile_6"]   = Conversion.uint64_to_bit_array(Conversion.uint8_array_to_uint64(Array(payload[81..<89])))
                    result["presenceProfile_7"]   = Conversion.uint64_to_bit_array(Conversion.uint8_array_to_uint64(Array(payload[89..<97])))
                    
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
