//
//  BehaviourHandler.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 22/10/2019.
//  Copyright © 2019 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth


public class BehaviourHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    func _handleResponse(data: [UInt8], seal: Resolver<BehaviourResultPacket>) {
        let resultPacket = ResultPacketV2(data)
        if resultPacket.valid == false {
            seal.reject(BluenetError.BEHAVIOUR_INVALID_RESPONSE)
            return
        }
        if resultPacket.resultCode == .SUCCESS {
            if resultPacket.payload.count >= 5 {
                let result = BehaviourResultPacket.init(
                    index: resultPacket.payload[0],
                    masterHash: Conversion.uint8_array_to_uint32([
                        resultPacket.payload[1],
                        resultPacket.payload[2],
                        resultPacket.payload[3],
                        resultPacket.payload[4]
                ]))
                seal.fulfill(result)
            }
            else {
                seal.reject(BluenetError.BEHAVIOUR_INVALID_RESPONSE)
            }
        }
        else {
            seal.reject(BluenetError.BEHAVIOUR_INVALID_RESPONSE)
        }
    }
    
    
    public func saveBehaviour(behaviour: Behaviour) -> Promise<BehaviourResultPacket> {
        return Promise<BehaviourResultPacket> { seal in
            let behaviourDataPacket = behaviour.getPacket()
            let packet = ControlPacketV2(type: .saveBehaviour, payloadArray: behaviourDataPacket).getPacket()
            
            let writeCommand : voidPromiseCallback = {
               return _writeGenericControlPacket(bleManager: self.bleManager, packet)
            }
            self.bleManager.setupSingleNotification(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.ResultV2, writeCommand: writeCommand)
                .done{ data -> Void in
                    self._handleResponse(data: data, seal: seal)
               }
               .catch{ err in seal.reject(err) }
            }
    }
    
    public func replaceBehaviour(index: UInt8, behaviour: Behaviour) -> Promise<BehaviourResultPacket> {
        return Promise<BehaviourResultPacket> { seal in
            
            var dataPacket = [UInt8]()
            dataPacket.append(index)
            dataPacket += behaviour.getPacket()
            
            let packet = ControlPacketV2(type: .replaceBehaviour, payloadArray: dataPacket).getPacket()
            
            let writeCommand : voidPromiseCallback = {
               return _writeGenericControlPacket(bleManager: self.bleManager, packet)
            }
            self.bleManager.setupSingleNotification(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.ResultV2, writeCommand: writeCommand)
                .done{ data -> Void in
                    self._handleResponse(data: data, seal: seal)
               }
               .catch{ err in seal.reject(err) }
        }
    }
    
    public func removeBehaviour(index: UInt8) -> Promise<BehaviourResultPacket> {
        return Promise<BehaviourResultPacket> { seal in
            let deletePacket = ControlPacketV2(type: .removeBehaviour, payload8: index).getPacket()
            let writeCommand : voidPromiseCallback = {
               return _writeGenericControlPacket(bleManager: self.bleManager, deletePacket)
            }
            self.bleManager.setupSingleNotification(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.ResultV2, writeCommand: writeCommand)
                .done{ data -> Void in
                    self._handleResponse(data: data, seal: seal)
               }
               .catch{ err in seal.reject(err) }
        }
    }
    
    public func getBehaviour(index: UInt8) -> Promise<Behaviour>  {
        return Promise<Behaviour> { seal in
            let getBehaviourPacket = ControlPacketV2(type: .getBehaviour, payload8: index).getPacket()
            let writeCommand : voidPromiseCallback = {
               return _writeGenericControlPacket(bleManager: self.bleManager, getBehaviourPacket)
            }
            self.bleManager.setupSingleNotification(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.ResultV2, writeCommand: writeCommand)
                .done{ data -> Void in
                    let resultPacket = ResultPacketV2(data)
                    if resultPacket.valid == false {
                        seal.reject(BluenetError.BEHAVIOUR_INVALID_RESPONSE)
                    }
                    if resultPacket.resultCode == .SUCCESS {
                        let behaviour = Behaviour(data: resultPacket.payload)
                        
                        // store the index into the behaviour
                        behaviour.indexOnCrownstone = index
                        
                        if (behaviour.valid) {
                            seal.fulfill(behaviour)
                        }
                        else {
                            seal.reject(BluenetError.BEHAVIOUR_INVALID)
                        }
                    }
                    else if resultPacket.resultCode == .NOT_FOUND {
                        seal.reject(BluenetError.BEHAVIOUR_NOT_FOUND_AT_INDEX)
                    }
                    else {
                        seal.reject(BluenetError.BEHAVIOUR_INVALID_RESPONSE)
                    }
               }
               .catch{ err in seal.reject(err) }
        }
    }
    
    public func getIndices() -> Promise<[IndexResultPacket]> {
        return Promise<[IndexResultPacket]> { seal in
            let getBehaviourPacket = ControlPacketV2(type: .getBehaviourIndices).getPacket()
            let writeCommand : voidPromiseCallback = {
               return _writeGenericControlPacket(bleManager: self.bleManager, getBehaviourPacket)
            }
            self.bleManager.setupSingleNotification(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.ResultV2, writeCommand: writeCommand)
                .done{ data -> Void in
                    let resultPacket = ResultPacketV2(data)
                    if resultPacket.valid == false {
                        seal.reject(BluenetError.BEHAVIOUR_INVALID_RESPONSE)
                        return
                    }
                    if resultPacket.resultCode == .SUCCESS {
                        let amountOfPackets = resultPacket.payload.count/5
                        
                        var result = [IndexResultPacket]()
                        for i in 0...amountOfPackets-1 {
                            let baseIndex = i*5
                            let packet = IndexResultPacket.init(
                                index: resultPacket.payload[baseIndex],
                                behaviourHash: Conversion.uint8_array_to_uint32([
                                    resultPacket.payload[baseIndex]+1,
                                    resultPacket.payload[baseIndex]+2,
                                    resultPacket.payload[baseIndex]+3,
                                    resultPacket.payload[baseIndex]+4
                                ]))
                            result.append(packet)
                        }
                        seal.fulfill(result)
                    }
                    else {
                        seal.reject(BluenetError.BEHAVIOUR_INVALID_RESPONSE)
                    }
               }
               .catch{ err in seal.reject(err) }
        }
    }
    
}


public struct BehaviourResultPacket {
    public var index: UInt8
    public var masterHash: UInt32
}

public struct IndexResultPacket {
    public var index: UInt8
    public var behaviourHash: UInt32
}
