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
    let handle : UUID
    
    init (handle: UUID, bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.handle     = handle
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    func _handleResponseIndexHash(resultPacket: ResultBasePacket, seal: Resolver<BehaviourResultPacket>, notFoundIsSuccess: Bool = false) {
        if resultPacket.valid == false {
            seal.reject(BluenetError.BEHAVIOUR_INVALID_RESPONSE)
            return
        }
        if resultPacket.resultCode == .SUCCESS || (notFoundIsSuccess == true && resultPacket.resultCode == .NOT_FOUND) {
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
    
    
    public func addBehaviour(behaviour: Behaviour) -> Promise<BehaviourResultPacket> {
        return Promise<BehaviourResultPacket> { seal in
            let behaviourDataPacket = behaviour.getPacket()
            let packet = ControlPacketsGenerator.getControlPacket(type: .addBehaviour).load(behaviourDataPacket).getPacket()
            
            _writePacketWithReply(bleManager: self.bleManager, handle :self.handle, packet)
                .done{ resultPacket -> Void in
                    self._handleResponseIndexHash(resultPacket: resultPacket, seal: seal)
               }
               .catch{ err in seal.reject(err) }
            }
    }
    
    public func replaceBehaviour(index: UInt8, behaviour: Behaviour) -> Promise<BehaviourResultPacket> {
        return Promise<BehaviourResultPacket> { seal in
            var dataPacket = [UInt8]()
            dataPacket.append(index)
            dataPacket += behaviour.getPacket()
            let packet = ControlPacketsGenerator.getControlPacket(type: .replaceBehaviour).load(dataPacket).getPacket()
        
            _writePacketWithReply(bleManager: self.bleManager, handle: self.handle, packet)
                .done{ resultPacket -> Void in
                    self._handleResponseIndexHash(resultPacket: resultPacket, seal: seal)
                }
               .catch{ err in seal.reject(err) }
        }
    }
    
    public func removeBehaviour(index: UInt8) -> Promise<BehaviourResultPacket> {
        return Promise<BehaviourResultPacket> { seal in
            let deletePacket = ControlPacketsGenerator.getControlPacket(type: .removeBehaviour).load(index).getPacket()
         
            _writePacketWithReply(bleManager: self.bleManager, handle: self.handle, deletePacket)
                 .done{ resultPacket -> Void in
                     self._handleResponseIndexHash(resultPacket: resultPacket, seal: seal, notFoundIsSuccess: true)
                 }
                .catch{ err in seal.reject(err) }
        }
    }
    
    public func getBehaviour(index: UInt8) -> Promise<Behaviour>  {
        return Promise<Behaviour> { seal in
            let getBehaviourPacket = ControlPacketsGenerator.getControlPacket(type: .getBehaviour).load(index).getPacket()
            
            let writeCommand : voidPromiseCallback = {
               return _writeControlPacketWithoutWaitingForReply(bleManager: self.bleManager, self.handle, getBehaviourPacket)
            }
            let readParameters = getControlReadParameters(bleManager: bleManager, handle: self.handle)
            self.bleManager.setupSingleNotification(self.handle, serviceId: readParameters.service, characteristicId: readParameters.characteristic, writeCommand: writeCommand)
                .done{ data -> Void in
                    let resultPacket = StatePacketsGenerator.getReturnPacket()
                    resultPacket.load(data)

                    if resultPacket.valid == false {
                        seal.reject(BluenetError.BEHAVIOUR_INVALID_RESPONSE)
                    }
                    if resultPacket.resultCode == .SUCCESS {
                        let indexStored = resultPacket.payload[0]
                        let behaviourData = Array(resultPacket.payload[1..<resultPacket.payload.count])
                        let behaviour = Behaviour(data: behaviourData)
                        
                        // store the index into the behaviour
                        behaviour.indexOnCrownstone = indexStored
                        
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
            let getBehaviourPacket = ControlPacketsGenerator.getControlPacket(type: .getBehaviourIndices).getPacket()
            
            let writeCommand : voidPromiseCallback = {
               return _writeControlPacketWithoutWaitingForReply(bleManager: self.bleManager, self.handle, getBehaviourPacket)
            }
            
            let readParameters = getControlReadParameters(bleManager: bleManager, handle: self.handle)
            self.bleManager.setupSingleNotification(self.handle, serviceId: readParameters.service, characteristicId: readParameters.characteristic, writeCommand: writeCommand)
                .done{ data -> Void in
                    let resultPacket = StatePacketsGenerator.getReturnPacket()
                    resultPacket.load(data)
                    
                    if resultPacket.valid == false {
                        seal.reject(BluenetError.BEHAVIOUR_INVALID_RESPONSE)
                        return
                    }
                    if resultPacket.resultCode == .SUCCESS {
                        var result = [IndexResultPacket]()
                        let amountOfPackets = resultPacket.payload.count/5
                        if (amountOfPackets > 0) {
                            for i in 0..<amountOfPackets {
                                let baseIndex = i*5
                                let packet = IndexResultPacket.init(
                                    index: resultPacket.payload[baseIndex],
                                    behaviourHash: Conversion.uint8_array_to_uint32([
                                        resultPacket.payload[baseIndex+1],
                                        resultPacket.payload[baseIndex+2],
                                        resultPacket.payload[baseIndex+3],
                                        resultPacket.payload[baseIndex+4]
                                    ]))
                                result.append(packet)
                            }
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
