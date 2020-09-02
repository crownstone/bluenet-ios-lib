//
//  StateHandler
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

public class StateHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    
    public func getErrors() -> Promise<CrownstoneErrors> {
        return Promise<CrownstoneErrors> { seal in
            self.getErrorBitmask()
                .done{ data -> Void in
                    let relevantDataArray = [data[0],data[1],data[2],data[3]]
                    let uint32 = Conversion.uint8_array_to_uint32(relevantDataArray)
                    let csError = CrownstoneErrors(bitMask: uint32)
                    seal.fulfill(csError)
                }
                .catch{ err in seal.reject(err) }
        }
    }
    
    public func getErrorBitmask() -> Promise<[UInt8]> {
        return self._getState(StateType.error_BITMASK)
    }
    
    public func getSwitchState() -> Promise<UInt8> {
        return self._getState(StateType.switch_STATE)
    }
    
    public func getResetCounter() -> Promise<UInt16> {
        return self._getState(StateType.reset_COUNTER)
    }
    
    public func getSwitchStateFloat() -> Promise<Float> {
        return Promise<Float> { seal in
            self.getSwitchState()
                .done{ switchState -> Void in
                    var returnState : Float = 0.0
                    if (switchState == 128) {
                        returnState = 1.0
                    }
                    else if (switchState <= 100) {
                        returnState = 0.01 * NSNumber(value: switchState).floatValue * 0.99
                    }
                    seal.fulfill(returnState)
                }
                .catch{ err in seal.reject(err) }
        }
    }
    
    public func getTime() -> Promise<NSNumber> {
        return Promise<NSNumber> { seal in
            let timePromise : Promise<UInt32> = self._getState(StateType.time)
            timePromise
                .done{ time -> Void in seal.fulfill(NSNumber(value: time))}
                .catch{ err in seal.reject(err) }
        }
    }
    
    
    func _writeToState(packet: [UInt8]) -> Promise<Void> {
        let params = _getStateWriteParameters()
        return self.bleManager.writeToCharacteristic(
            params.service,
            characteristicId: params.characteristic,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
       )
    }
   
    public func _getState<T>(_ state : StateType) -> Promise<T> {
        let mappedStateType = StateTypeV3(rawValue: UInt16(state.rawValue))!
        let readpacket = StatePacketsGenerator.getReadPacket(type: mappedStateType).getPacket()
        return self._getState(readpacket)
    }
    
    public func _getState<T>(_ state : StateTypeV3, id: UInt16 = 0) -> Promise<T> {
        let readpacket = StatePacketsGenerator.getReadPacket(type: state, id: id).getPacket()
        return self._getState(readpacket, id: 0)
    }
    
    public func _getState<T>(_ requestPacket: [UInt8], id: UInt16 = 0) -> Promise<T> {
        let stateParams = _getStateReadParameters()
        
        return Promise<T> { seal in
            let writeCommand : voidPromiseCallback = { 
                return self._writeToState(packet: requestPacket)
            }
            
            _writePacketWithReply(bleManager: self.bleManager, service: stateParams.service, readCharacteristic: stateParams.characteristic, writeCommand: writeCommand)
                .done{ resultPacket -> Void in
                    do {
                        let result : T = try getConfigPayloadFromResultPacket(self.bleManager, resultPacket)
                        seal.fulfill(result)
                    }
                    catch let err {
                        seal.reject(err)
                    }
                }
                .catch{ err in seal.reject(err) }
        }
    }
    
    func _getStateReadParameters() -> BleParameters {
        let service = CSServices.CrownstoneService;
        
        //determine where to listen to
        var characteristicToReadFrom : String
        switch (self.bleManager.connectionState.connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                characteristicToReadFrom = CrownstoneCharacteristics.StateRead
            case .v3:
                characteristicToReadFrom = CrownstoneCharacteristics.ResultV3
            case .v5:
                characteristicToReadFrom = CrownstoneCharacteristics.ResultV5
        }
        
        return BleParameters(service: service, characteristic: characteristicToReadFrom)
    }
    
    func _getStateWriteParameters() -> BleParameters {
        let service = CSServices.CrownstoneService;
        
        //determine where to write
        var characteristicToWriteTo : String
        
        switch (self.bleManager.connectionState.connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                characteristicToWriteTo = CrownstoneCharacteristics.Control
            case .v3:
                characteristicToWriteTo = CrownstoneCharacteristics.ControlV3
            case .v5:
                characteristicToWriteTo = CrownstoneCharacteristics.ControlV5
        }
        
        return BleParameters(service: service, characteristic: characteristicToWriteTo)
    }
    
}
