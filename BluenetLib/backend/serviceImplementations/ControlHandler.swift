//
//  ControlHandler.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

public class ControlHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    var disconnectCommandTimeList : [String: Double]!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    public func recoverByFactoryReset(_ uuid: String) -> Promise<Void> {
        LOG.info("BLUENET_LIB: recoverByFactoryReset \(uuid)")
        self.bleManager.connectionState.disableEncryptionTemporarily()
        return Promise<Void> { seal in
            self.bleManager.isReady() // first check if the bluenet lib is ready before using it for BLE things.
                .then {(_) -> Promise<Void> in return self.bleManager.connect(uuid)}
                .then {(_) -> Promise<Void> in return self._recoverByFactoryReset()}
                .then {(_) -> Promise<Void> in return self._checkRecoveryProcess()}
                .then {(_) -> Promise<Void> in return self.bleManager.disconnect()}
                .then {(_) -> Promise<Void> in return self.bleManager.waitToReconnect()}
                .then {(_) -> Promise<Void> in return self.bleManager.connect(uuid)}
                .then {(_) -> Promise<Void> in return self._recoverByFactoryReset()}
                .then {(_) -> Promise<Void> in return self._checkRecoveryProcess()}
                .then {(_) -> Promise<Void> in
                    self.bleManager.connectionState.restoreEncryption()
                    return self.bleManager.disconnect()
                }
                .done {(_) -> Void in seal.fulfill(())}
                .catch {(err) -> Void in
                    self.bleManager.connectionState.restoreEncryption()
                    self.bleManager.disconnect().done{_ in seal.reject(err)}.catch{_ in seal.reject(err)}
                }
        }
    }

    
    func _checkRecoveryProcess() -> Promise<Void> {
        return Promise<Void> { seal in
            self.bleManager.readCharacteristic(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.FactoryReset)
                .done{(result: [UInt8]) -> Void in
                    if (result[0] == 1) {
                        seal.fulfill(())
                    }
                    else if (result[0] == 2) {
                        seal.reject(BluenetError.RECOVER_MODE_DISABLED)
                    }
                    else {
                        seal.reject(BluenetError.NOT_IN_RECOVERY_MODE)
                    }
                }
                .catch{(err) -> Void in
                    seal.reject(BluenetError.CANNOT_READ_FACTORY_RESET_CHARACTERISTIC)
                }
        }
    }
    
    func _recoverByFactoryReset() -> Promise<Void> {
        let packet = ControlPacketsGenerator.getFactoryResetPacket()
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.FactoryReset,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    public func sendNoOp() -> Promise<Void> {
        let packet = ControlPacketsGenerator.getNoOpPacket()
        return _writeControlPacket(bleManager: self.bleManager, packet)
    }
    
    public func commandFactoryReset() -> Promise<Void> {
        var writeWasSuccessful = false
        let writeCommand : voidPromiseCallback = { return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getCommandFactoryResetPacket()) }
        return _writePacketWithReply(bleManager: self.bleManager, writeCommand: writeCommand)
            .then{ responseBasePacket in
                return Promise<Void> { seal in
                    if (responseBasePacket.valid) {
                        seal.fulfill(())
                    }
                    else {
                        if (responseBasePacket.data[0] == 0 && self.bleManager.connectionState.proto) {
                             seal.fulfill()
                        }
                        else {
                            seal.reject(BluenetError.COULD_NOT_FACTORY_RESET)
                        }
                    }
                    
                }
            }
            .recover{(err: Error) -> Promise<Void> in
                return Promise <Void> { seal in
                    // we only want to pass this to the main promise of connect if we successfully received the nonce, but cant decrypt it.
                    if let bleErr = err as? BluenetError {
                        if bleErr == BluenetError.DISCONNECTED && writeWasSuccessful == true {
                            seal.fulfill(())
                            return
                        }
                    }
                    seal.reject((err))
                }
        }
    }
    
    public func pulse() -> Promise<Void> {
        let switchOn  = ControlPacketsGenerator.getSwitchStatePacket(1)
        let switchOff = ControlPacketsGenerator.getSwitchStatePacket(0)
        return Promise<Void> { seal in
            _writeControlPacket(bleManager: self.bleManager, switchOn)
                .then{ self.bleManager.wait(seconds: 1) }
                .then{ _writeControlPacket(bleManager: self.bleManager, switchOff) }
                .done{
                    _ = self.bleManager.disconnect();
                    seal.fulfill(())
                }
                .catch{(err: Error) -> Void in
                    _ = self.bleManager.errorDisconnect()
                    seal.reject(err)
                }
        }
    }
    
    /**
     * Switches power intelligently.
     * State has to be between 0 and 1
     */
    public func setSwitchState(_ state: Float) -> Promise<Void> {
        let packet = ControlPacketsGenerator.getSwitchStatePacket(state)
        return _writeControlPacket(bleManager: self.bleManager, packet)
    }
    
    public func reset() -> Promise<Void> {
        LOG.info("BLUENET_LIB: requesting reset")
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getResetPacket())
    }
    
    public func putInDFU() -> Promise<Void> {
        if self.bleManager.connectionState.operationMode == .dfu {
            LOG.info("BLUENET_LIB: Already in DFU.")
            return Promise.value(())
        }
        else {
            LOG.info("BLUENET_LIB: switching to DFU")
            return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getPutInDFUPacket())
        }
    }
    
    public func disconnect() -> Promise<Void> {
        var connectedHandle : String? = nil
        if (self.bleManager.connectedPeripheral != nil) {
            connectedHandle = self.bleManager.connectedPeripheral!.identifier.uuidString
        }
        LOG.info("BLUENET_LIB: REQUESTING IMMEDIATE DISCONNECT FROM \(String(describing: connectedHandle))")
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getDisconnectPacket())
            .then{_ -> Promise<Void> in
                LOG.info("BLUENET_LIB: Written disconnect command, emitting event for... \(String(describing: connectedHandle))")
                if (connectedHandle != nil) {
                    self.eventBus.emit("disconnectCommandWritten", connectedHandle!)
                }
                
                return self.bleManager.disconnect()
            }
    }
    
    
    /**
     State is a number: 0 or 1
     */
    public func switchRelay(_ state: UInt8) -> Promise<Void> {
        LOG.info("BLUENET_LIB: switching relay to \(state)")
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getRelaySwitchPacket(state))
    }
    
    
    /**
     * This method will ask the current switch state and listen to the notification response. 
     * It will then switch the crownstone. If it was > 0 --> 0 if it was 0 --> 1.
     **/
    public func toggleSwitchState(stateForOn : Float = 1.0) -> Promise<Float> {
        let stateHandler = StateHandler(bleManager: self.bleManager, eventBus: self.eventBus, settings: self.settings)
        return Promise<Float> { seal -> Void in
            var newSwitchState : Float = 0;
            stateHandler.getSwitchState()
                .then{ currentSwitchState -> Promise<Void> in
                    if (currentSwitchState == 0) {
                        newSwitchState = stateForOn
                    }
                    return self.setSwitchState(newSwitchState)
                }
                .done{ _ in seal.fulfill(newSwitchState) }
                .catch{(err) -> Void in
                    seal.reject(err)
                }
        }
    }
    
    
    /**
    State is a number between 0 and 1
    */
    public func switchPWM(_ state: Float) -> Promise<Void> {
        LOG.info("BLUENET_LIB: switching PWM to \(state)")
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getPwmSwitchPacket(state))
    }
    
    public func setTime(_ newTime: NSNumber) -> Promise<Void> {
        LOG.info("BLUENET_LIB: setting the TIME to \(newTime.uint32Value)")
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getSetTimePacket(newTime.uint32Value))
    }
    
    public func clearError(errorDict: NSDictionary) -> Promise<Void> {
        let resetErrorMask = CrownstoneErrors(dictionary: errorDict).getResetMask()
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getResetErrorPacket(errorMask: resetErrorMask))
    }
    
    
    /**
     * If the changeState is true, then the state and timeout will be used. If it is false, the keepaliveState on the Crownstone will be cleared and nothing will happen when the timer runs out.
     */
    public func keepAliveState(changeState: Bool, state: Float, timeout: UInt16) -> Promise<Void> {
        LOG.info("BLUENET_LIB: Keep alive State")
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getKeepAliveStatePacket(changeState: changeState, state: state, timeout: timeout))
    }
    
    public func keepAliveRepeat() -> Promise<Void> {
        LOG.info("BLUENET_LIB: Keep alive")
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getKeepAliveRepeatPacket())
    }
    
    public func allowDimming(allow: Bool) -> Promise<Void> {
        LOG.info("BLUENET_LIB: allowDimming")
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getAllowDimmingPacket(allow))
    }
     
    public func lockSwitch(lock: Bool) -> Promise<Void> {
        LOG.info("BLUENET_LIB: lockSwitch")
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getLockSwitchPacket(lock))
    }
     
    
    /**
     * The session nonce is the only char that is ECB encrypted. We therefore read it without the libraries decryption (AES CTR) and decrypt it ourselves.
     **/
    public func getAndSetSessionNonce() -> Promise<Void> {
        LOG.info("BLUENET_LIB: getAndSetSessionNonce")
        let sessionParameters = getSessionNonceReadParameters(bleManager: self.bleManager)
        
        return self.bleManager.readCharacteristicWithoutEncryption(sessionParameters.service, characteristic: sessionParameters.characteristic)
            .then{(sessionData : [UInt8]) -> Promise<Void> in
                return Promise <Void> { seal in
                    do {
                        if let basicKey = self.bleManager.connectionState.getBasicKey() {
                            try EncryptionHandler.processSessionData(sessionData, key: basicKey, connectionState: self.bleManager.connectionState)
                            seal.fulfill(())
                        }
                        else {
                            throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY
                        }
                    }
                    catch let err {
                        seal.reject(err)
                    }
                }
            }
            .recover{(err: Error) -> Promise<Void> in
                return Promise <Void> { seal in
                    // we only want to pass this to the main promise of connect if we successfully received the nonce, but cant decrypt it.
                    if let bleErr = err as? BluenetError {
                        if bleErr == BluenetError.COULD_NOT_VALIDATE_SESSION_NONCE || bleErr == BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY {
                            seal.reject(err)
                            return
                        }
                    }
                    seal.fulfill(())
                }
            }
    }
    
    /**
     * This is used to configure the scheduler. The ScheduleConfigurator can be used to configure the data without knowing the protocol.
     **/
    public func setSchedule(scheduleConfig: ScheduleConfigurator) -> Promise<Void> {
        if (scheduleConfig.scheduleEntryIndex > 9) {
            return Promise<Void> { seal in seal.reject(BluenetError.INCORRECT_SCHEDULE_ENTRY_INDEX) }
        }
        let packet = ControlPacketsGenerator.getSetSchedulePacket(data: scheduleConfig.getPacket())

        return _writeControlPacket(bleManager: self.bleManager, packet)
    }
    
    
    /**
     * There are 10 schedulers. You pick which one you want to clear with the timerIndex which can be 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
     **/
    public func clearSchedule(scheduleEntryIndex: UInt8) -> Promise<Void> {
        if (scheduleEntryIndex > 9) {
            return Promise<Void> { seal in seal.reject(BluenetError.INCORRECT_SCHEDULE_ENTRY_INDEX) }
        }
        
        return _writeControlPacket(bleManager: self.bleManager, ControlPacketsGenerator.getScheduleRemovePacket(timerIndex: scheduleEntryIndex))
    }
    
    
    public func registerTrackedDevice(
        trackingNumber: UInt16,
        locationUid: UInt8,
        profileId: UInt8,
        rssiOffset: UInt8,
        ignoreForPresence: Bool,
        tapToToggle: Bool,
        deviceToken: UInt32,
        ttlMinutes: UInt16
    ) -> Promise<Void> {
        return self._writeControlPacketWithReply(ControlPacketsGenerator.getTrackedDeviceRegistrationPacket(
            trackingNumber: trackingNumber,
            locationUid: locationUid,
            profileId: profileId,
            rssiOffset: rssiOffset,
            ignoreForPresence: ignoreForPresence,
            tapToToggle: tapToToggle,
            deviceToken: deviceToken,
            ttlMinutes: ttlMinutes
        ))
        
    }

    
    
    // MARK: Util
    public func _writeControlPacketWithReply(_ packet: [UInt8]) -> Promise<Void> {
        return Promise { seal in
            let writeCommand : voidPromiseCallback = { return _writeControlPacket(bleManager: self.bleManager, packet) }
            
            _writePacketWithReply(bleManager: self.bleManager, writeCommand: writeCommand)
               .done{ resultPacket -> Void in
                    if resultPacket.resultCode == .SUCCESS {
                        seal.fulfill(())
                    }
                    else if resultPacket.resultCode == .ERR_ALREADY_EXISTS {
                        seal.reject(BluenetError.ERR_ALREADY_EXISTS)
                    }
                }
                .catch{ err in seal.reject(err) }
        }
       
    }
}
