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
                return _writeControlPacket(bleManager: self.bleManager, ControlPacketV3(type: .getBehaviourDebug).getPacket())
            }
            self.bleManager.setupSingleNotification(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.ResultV3, writeCommand: writeCommand)
                .done{ data -> Void in

                    var result = Dictionary<String,Any>()
                    let resultPacket = ResultPacketV3()
                    resultPacket.load(data)
                    if (resultPacket.valid == false) {
                        return seal.reject(BluenetError.INCORRECT_RESPONSE_LENGTH)
                    }
                    let payload = DataStepper(resultPacket.payload)
                    
                    do {
                        result["time"]                = try payload.getUInt32()
                        result["sunrise"]             = try payload.getUInt32()
                        result["sunset"]              = try payload.getUInt32()

                        result["overrideState"]       = try payload.getUInt8()
                        result["behaviourState"]      = try payload.getUInt8()
                        result["aggregatedState"]     = try payload.getUInt8()
                        result["dimmerPowered"]       = try payload.getUInt8()
                        result["behaviourEnabled"]    = try payload.getUInt8()

                        if (resultPacket.size > 105) {
                            result["storedBehaviours"]    = Conversion.uint64_to_bit_array(try payload.getUInt64())
                        }
                        result["activeBehaviours"]    = Conversion.uint64_to_bit_array(try payload.getUInt64())
                        result["activeEndConditions"] = Conversion.uint64_to_bit_array(try payload.getUInt64())
                        
                        result["behavioursInTimeoutPeriod"] = Conversion.uint64_to_bit_array(try payload.getUInt64())
                        
                        result["presenceProfile_0"]   = Conversion.uint64_to_bit_array(try payload.getUInt64())
                        result["presenceProfile_1"]   = Conversion.uint64_to_bit_array(try payload.getUInt64())
                        result["presenceProfile_2"]   = Conversion.uint64_to_bit_array(try payload.getUInt64())
                        result["presenceProfile_3"]   = Conversion.uint64_to_bit_array(try payload.getUInt64())
                        result["presenceProfile_4"]   = Conversion.uint64_to_bit_array(try payload.getUInt64())
                        result["presenceProfile_5"]   = Conversion.uint64_to_bit_array(try payload.getUInt64())
                        result["presenceProfile_6"]   = Conversion.uint64_to_bit_array(try payload.getUInt64())
                        result["presenceProfile_7"]   = Conversion.uint64_to_bit_array(try payload.getUInt64())
                    }
                    catch {
                        seal.reject(BluenetError.INVALID_DATA_LENGTH)
                        return
                    }
                    
                    seal.fulfill(result)
                }
                .catch{ err in seal.reject(err) }
        }
    }    
}

