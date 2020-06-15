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


public enum PowerSampleType : UInt8 {
    case triggeredSwitchcraft = 0
    case missedSwitchcraft    = 1
    case filteredBuffer       = 2
    case unfilteredBuffer     = 3
    case softFuse             = 4
}
public let PowerSampleTypeBufferCount : [UInt8: UInt8] = [
    0: 3,
    1: 3,
    2: 2,
    3: 2,
    4: 1
]

class Collector {
    var data : [Dictionary<String, Any>]
    init() {
        self.data = [Dictionary<String, Any>]()
    }
    func collect(_ d: Dictionary<String, Any>) {
        self.data.append(d)
    }
}

public class DebugHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    
    public func getUptime() -> Promise<UInt32> {
        return Promise<UInt32> { seal in
            let packet = ControlPacketsGenerator.getControlPacket(type: .getUptime).getPacket()
            let writeCommand : voidPromiseCallback = { return _writeControlPacket(bleManager: self.bleManager, packet) }
            
            _writePacketWithReply(bleManager: self.bleManager, writeCommand: writeCommand)
                .done { resultPacket in
                    let payload = DataStepper(resultPacket.payload)
                    do { seal.fulfill(try payload.getUInt32()) }
                    catch let err { seal.reject(err) }
                }
                .catch{ err in seal.reject(err)}
            }
    }
    
    
    public func getAdcRestarts() -> Promise<Dictionary<String, NSNumber>> {
        return Promise<Dictionary<String, NSNumber>> { seal in
            let packet = ControlPacketsGenerator.getControlPacket(type: .getAdcRestart).getPacket()
            let writeCommand : voidPromiseCallback = { return _writeControlPacket(bleManager: self.bleManager, packet) }
            
            _writePacketWithReply(bleManager: self.bleManager, writeCommand: writeCommand)
                .done { resultPacket in
                    let payload = DataStepper(resultPacket.payload)
                    do {
                        let restartCount = try payload.getUInt32()
                        let timestamp    = try payload.getUInt32()
                        
                        seal.fulfill([
                            "restartCount": NSNumber(value: restartCount),
                            "timestamp":    NSNumber(value: timestamp)
                        ])
                    }
                    catch let err { seal.reject(err) }
                }
                .catch{ err in seal.reject(err)}
            }
    }
    
    
    public func getSwitchHistory() -> Promise<[Dictionary<String, NSNumber>]> {
        return Promise<[Dictionary<String, NSNumber>]> { seal in
            let packet = ControlPacketsGenerator.getControlPacket(type: .getSwitchHistory).getPacket()
            let writeCommand : voidPromiseCallback = { return _writeControlPacket(bleManager: self.bleManager, packet) }

            _writePacketWithReply(bleManager: self.bleManager, writeCommand: writeCommand)
                .done { resultPacket in
                    do {
                        let package = try SwitchHistoryList(resultPacket.payload)
                        seal.fulfill(package.items)
                    }
                    catch let err { seal.reject(err) }
                }
                .catch{ err in seal.reject(err)}
            }
    }
    
    
    public func getPowerSamples(type: PowerSampleType) -> Promise<[Dictionary<String, Any>]> {
        return Promise<[Dictionary<String, Any>]> { seal in
            let collector = Collector()
            let amountOfBuffers : UInt8 = PowerSampleTypeBufferCount[type.rawValue]!
            
            var promiseArray = [voidPromiseCallback]()
            for i in (0...amountOfBuffers - 1) {
                promiseArray.append({ return self._getPowerSamples(type: type, index: NSNumber(value:i).uint8Value, collector: collector) })
            }
            
            promiseBatchPerformer(arr: promiseArray, index: 0)
                .done { _ in seal.fulfill(collector.data) }
                .catch{ err in seal.reject(err) }
        }
    }

    
    func _getPowerSamples(type: PowerSampleType, index: UInt8, collector: Collector) -> Promise<Void> {
        let packetIndex = ControlPacketsGenerator.getControlPacket(type: .getPowerSamples).load([type.rawValue, index]).getPacket()
        let writeCommandIndex : voidPromiseCallback = { return _writeControlPacket(bleManager: self.bleManager, packetIndex) }
        
        return _writePacketWithReply(bleManager: self.bleManager, writeCommand: writeCommandIndex)
            .done { resultPacket -> Void in
                let package = try PowerSamples(resultPacket.payload)
                collector.collect(package.getDict())
            }
    }
    

    
    public func getBehaviourDebugInformation() -> Promise<Dictionary<String,Any>> {
        return Promise<Dictionary<String,Any>> { seal in
            let getBehaviourPacket = ControlPacketsGenerator.getControlPacket(type: .getBehaviourDebug).getPacket()
            
            let writeCommand : voidPromiseCallback = {
               return _writeControlPacket(bleManager: self.bleManager, getBehaviourPacket)
            }
            let readParameters = getControlReadParameters(bleManager: bleManager)
            self.bleManager.setupSingleNotification(readParameters.service, characteristicId: readParameters.characteristic, writeCommand: writeCommand)
                .done{ data -> Void in

                    var result = Dictionary<String,Any>()
                    let resultPacket = StatePacketsGenerator.getReturnPacket()
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

