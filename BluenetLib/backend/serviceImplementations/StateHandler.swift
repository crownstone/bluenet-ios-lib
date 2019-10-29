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
    
    public func getAllSchedules() -> Promise<[ScheduleConfigurator]> {
        return Promise<[ScheduleConfigurator]> { seal in
            let dataPromise : Promise<[UInt8]> = self._getState(StateType.schedule)
            dataPromise
                .done{ data -> Void in
                    if (data.count == 0) {
                        LOG.error("Got empty list from scheduler state")
                        seal.reject(BluenetError.INCORRECT_DATA_COUNT_FOR_ALL_TIMERS)
                        return
                    }
            
                    let amountOfTimers : UInt8 = data[0]
                    
                    if (amountOfTimers == 0) {
                        seal.reject(BluenetError.NO_TIMER_FOUND)
                        return
                    }
                    
                    let amountOfDatapoints : UInt8 = 12
                    
                    let amountOfTimersInt : Int = NSNumber(value: amountOfTimers).intValue
                    let amountOfDatapointsInt : Int = NSNumber(value: amountOfDatapoints).intValue
                    
                    let totalCount : Int = 1 + amountOfTimersInt * amountOfDatapointsInt
                    
                    if (data.count < totalCount) {
                        LOG.error("Got list of size \(data.count) from scheduler state: \(data)")
                        seal.reject(BluenetError.INCORRECT_DATA_COUNT_FOR_ALL_TIMERS)
                        return
                    }
                    
                    var result = [ScheduleConfigurator]()
                    for i in [Int](0...amountOfTimersInt-1) {
                        var datablock = [UInt8]()
                        for j in [Int](0...amountOfDatapointsInt-1) {
                            datablock.append(data[i*amountOfDatapointsInt + j + 1])
                        }
                        result.append(ScheduleConfigurator(scheduleEntryIndex: NSNumber(value: i).uint8Value, data: datablock))
                    }
                    
                    seal.fulfill(result)
                    
                }
                .catch{ err in seal.reject(err) }
        }
    }
    
    public func getAvailableScheduleEntryIndex() -> Promise<UInt8> {
        return Promise<UInt8> { seal in
            self.getAllSchedules()
                .done{ schedules -> Void in
                    for schedule in schedules {
                        if (schedule.isAvailable()) {
                            seal.fulfill(schedule.scheduleEntryIndex)
                            return
                        }
                    }
                    seal.reject(BluenetError.NO_SCHEDULE_ENTRIES_AVAILABLE)
                }
                .catch{ err in seal.reject(err) }
        }
    }
    
    func _writeToState(packet: [UInt8]) -> Promise<Void> {
        if self.bleManager.connectionState.controlVersion == .v2 {
            return self.bleManager.writeToCharacteristic(
                CSServices.CrownstoneService,
                characteristicId: CrownstoneCharacteristics.ControlV2,
                data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
                type: CBCharacteristicWriteType.withResponse
            )
        }
        else {
            return self.bleManager.writeToCharacteristic(
                CSServices.CrownstoneService,
                characteristicId: CrownstoneCharacteristics.StateControl,
                data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
                type: CBCharacteristicWriteType.withResponse
            )
        }
    }
   
    public func _getState<T>(_ state : StateType) -> Promise<T> {
        return self._getState(StateTypeV2(rawValue: UInt16(state.rawValue))!)
    }
    
    public func _getState<T>(_ state : StateTypeV2) -> Promise<T> {
        return Promise<T> { seal in
            let stateParams = _getStateReadParameters()
            
            let writeCommand : voidPromiseCallback = { 
                return self._writeToState(packet: StatePacketsGenerator.getReadPacket(type: state).getPacket())
            }
            self.bleManager.setupSingleNotification(stateParams.service, characteristicId: stateParams.characteristicToReadFrom, writeCommand: writeCommand)
                .done{ data -> Void in
                    let resultPacket = StatePacketsGenerator.getReturnPacket()
                    resultPacket.load(data)
                    if (resultPacket.valid == false) {
                        return seal.reject(BluenetError.INCORRECT_RESPONSE_LENGTH)
                    }
                                        
                    do {
                        let result : T = try Convert(resultPacket.payload)
                        seal.fulfill(result)
                    }
                    catch let err {
                        seal.reject(err)
                    }
                }
                .catch{ err in seal.reject(err) }
        }
    }
    
    func _getStateReadParameters() -> ReadParamaters {
        let service                  = CSServices.CrownstoneService;
        var characteristicToReadFrom = CrownstoneCharacteristics.StateRead
        
        //determine where to write
        if self.bleManager.connectionState.controlVersion == .v2 {
            characteristicToReadFrom = CrownstoneCharacteristics.ResultV2
        }
        
        return ReadParamaters(service: service, characteristicToReadFrom: characteristicToReadFrom)
    }
    
}
