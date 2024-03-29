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
    var handle : UUID
    
    init (handle: UUID, bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.handle     = handle
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    public func recoverByFactoryReset() -> Promise<Void> {
        LOG.info("BLUENET_LIB: recoverByFactoryReset \(self.handle)")
        self.bleManager.connectionState(handle).disableEncryptionTemporarily()
        return Promise<Void> { seal in
            self.bleManager.isReady() // first check if the bluenet lib is ready before using it for BLE things.
                .then {(_) -> Promise<Void> in return self.bleManager.connect(self.handle.uuidString, timeout: timeoutDurations.connect)}
                .then {(_) -> Promise<Void> in return self._recoverByFactoryReset()}
                .then {(_) -> Promise<Void> in return self._checkRecoveryProcess()}
                .then {(_) -> Promise<Void> in return self.bleManager.disconnect(self.handle.uuidString)}
                .then {(_) -> Promise<Void> in
                    self.bleManager.connectionState(self.handle).disableEncryptionTemporarily()
                    return self.bleManager.waitToReconnect()
                }
                .then {(_) -> Promise<Void> in return self.bleManager.connect(self.handle.uuidString, timeout: timeoutDurations.connect)}
                .then {(_) -> Promise<Void> in return self._recoverByFactoryReset()}
                .then {(_) -> Promise<Void> in return self._checkRecoveryProcess()}
                .then {(_) -> Promise<Void> in
                    self.bleManager.connectionState(self.handle).restoreEncryption()
                    return self.bleManager.disconnect(self.handle.uuidString)
                }
                .done {(_) -> Void in seal.fulfill(())}
                .catch {(err) -> Void in
                    LOG.error("BLUENET_LIB: recoverByFactoryReset ERROR \(err)")
                    self.bleManager.connectionState(self.handle).restoreEncryption()
                    self.bleManager.disconnect(self.handle.uuidString).done{_ in seal.reject(err)}.catch{_ in seal.reject(err)}
                }
        }
    }

    
    func _checkRecoveryProcess() -> Promise<Void> {
        return Promise<Void> { seal in
            self.bleManager.readCharacteristic(self.handle, serviceId: CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.FactoryReset)
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
            self.handle,
            serviceId: CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.FactoryReset,
            data: Data(bytes: packet, count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    public func sendNoOp() -> Promise<Void> {
        let packet = ControlPacketsGenerator.getNoOpPacket()
        return _writeControlPacket(bleManager: self.bleManager, handle, packet)
    }
    
    public func commandFactoryReset() -> Promise<Void> {
        var writeWasSuccessful = false
        let writeCommand : voidPromiseCallback = { () -> Promise<Void> in
            return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getCommandFactoryResetPacket())
                .then { _ -> Promise<Void> in
                    writeWasSuccessful = true
                    return Promise<Void>{ seal in  seal.fulfill(()) }
                }
        }
        return _writePacketWithReply(bleManager: self.bleManager, handle: self.handle, writeCommand: writeCommand)
            .then{ responseBasePacket in
                return Promise<Void> { seal in
                    if (responseBasePacket.valid) {
                        seal.fulfill(())
                    }
                    else {
                        if (responseBasePacket.data[0] == 0 && self.bleManager.connectionState(self.handle).connectionProtocolVersion.rawValue < ConnectionProtocolVersion.v3.rawValue) {
                             seal.fulfill(())
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
        let switchOn  = ControlPacketsGenerator.getSwitchStatePacket(100)
        let switchOff = ControlPacketsGenerator.getSwitchStatePacket(0)
        return Promise<Void> { seal in
            _writeControlPacket(bleManager: self.bleManager, self.handle, switchOn)
                .then{ self.bleManager.wait(seconds: 1) }
                .then{ _writeControlPacket(bleManager: self.bleManager, self.handle, switchOff) }
                .done{
                    _ = self.bleManager.disconnect(self.handle.uuidString);
                    seal.fulfill(())
                }
                .catch{(err: Error) -> Void in
                    _ = self.bleManager.errorDisconnect(self.handle.uuidString)
                    seal.reject(err)
                }
        }
    }
    
    
    
    
    
    /**
     * Switches power intelligently.
     * State has to be between 0 and 1
     */
    public func setSwitchState(_ state: UInt8) -> Promise<Void> {
        let packet = ControlPacketsGenerator.getSwitchStatePacket(state)
        return _writeControlPacket(bleManager: self.bleManager, self.handle, packet)
    }
    
    public func reset() -> Promise<Void> {
        LOG.info("BLUENET_LIB: requesting reset")
        return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getResetPacket())
    }
    
    public func putInDFU() -> Promise<Void> {
        if self.bleManager.connectionState(self.handle).operationMode == .dfu {
            LOG.info("BLUENET_LIB: Already in DFU.")
            return Promise.value(())
        }
        else {
            LOG.info("BLUENET_LIB: switching to DFU")
            return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getPutInDFUPacket())
        }
    }
    
    public func disconnect() -> Promise<Void> {
        LOG.info("BLUENET_LIB: REQUESTING IMMEDIATE DISCONNECT FROM \(self.handle)")
        var disconnectStarted = false
        return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getDisconnectPacket())
            .then{_ -> Promise<Void> in
                LOG.info("BLUENET_LIB: Written disconnect command, emitting event for... \(self.handle)")
                disconnectStarted = true
                LOG.info("BLUENET_LIB: Disconnecting in library... \(self.handle)")
                return self.bleManager.disconnect(self.handle.uuidString)
            }
            .recover { err -> Promise<Void> in
                if (disconnectStarted == false) {
                    LOG.info("BLUENET_LIB: Disconnecting in library... (recover from \(err)) \(self.handle)")
                    return self.bleManager.disconnect(self.handle.uuidString)
                }
                else {
                    return Promise.value(())
                }
            }
    }
    
    
    /**
     State is a number: 0 or 1
     */
    public func switchRelay(_ state: UInt8) -> Promise<Void> {
        LOG.info("BLUENET_LIB: switching relay to \(state)")
        return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getRelaySwitchPacket(state))
    }
    
    
    /**
     * This method will ask the current switch state and listen to the notification response. 
     * It will then switch the crownstone. If it was > 0 --> 0 if it was 0 --> 1.
     **/
    public func toggleSwitchState(stateForOn : UInt8 = 100) -> Promise<UInt8> {
        let stateHandler = StateHandler(handle: handle, bleManager: self.bleManager, eventBus: self.eventBus, settings: self.settings)
        return Promise<UInt8> { seal -> Void in
            var newSwitchState : UInt8 = 0;
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
    public func switchPWM(_ state: UInt8) -> Promise<Void> {
        LOG.info("BLUENET_LIB: switching PWM to \(state)")
        return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getPwmSwitchPacket(state))
    }
    
    public func setTime(_ newTime: NSNumber) -> Promise<Void> {
        LOG.info("BLUENET_LIB: setting the TIME to \(newTime.uint32Value)")
        return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getSetTimePacket(newTime.uint32Value))
    }
    
    public func clearError(errorDict: NSDictionary) -> Promise<Void> {
        let resetErrorMask = CrownstoneErrors(dictionary: errorDict).getResetMask()
        return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getResetErrorPacket(errorMask: resetErrorMask))
    }
    
    
    public func allowDimming(allow: Bool) -> Promise<Void> {
        LOG.info("BLUENET_LIB: allowDimming")
        return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getAllowDimmingPacket(allow))
    }
     
    public func lockSwitch(lock: Bool) -> Promise<Void> {
        LOG.info("BLUENET_LIB: lockSwitch")
        return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getLockSwitchPacket(lock))
    }
     
    

    
    
    /**
     * The session nonce is the only char that is ECB encrypted. We therefore read it without the libraries decryption (AES CTR) and decrypt it ourselves.
     **/
    public func getAndSetSessionNonce() -> Promise<Void> {
        LOG.info("BLUENET_LIB: getAndSetSessionNonce \(self.handle)")
        let sessionParameters = getSessionNonceReadParameters(bleManager: self.bleManager, handle: self.handle)
        
        return self.bleManager.readCharacteristicWithoutEncryption(self.handle, service: sessionParameters.service, characteristic: sessionParameters.characteristic)
            .then{(sessionData : [UInt8]) -> Promise<Void> in
                return Promise <Void> { seal in
                    
                    switch (self.bleManager.connectionState(self.handle).connectionProtocolVersion) {
                    case .unknown, .legacy, .v1, .v2, .v3, .v5:
                        do {
                            if let basicKey = self.bleManager.connectionState(self.handle).getBasicKey() {
                                try EncryptionHandler.processSessionData(sessionData, key: basicKey, connectionState: self.bleManager.connectionState(self.handle))
                                seal.fulfill(())
                            }
                            else {
                                throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY
                            }
                        }
                        catch let err {
                            seal.reject(err)
                        }
                        return;
                    case .v5_2:
                        do {
                            let payload = DataStepper(sessionData)
                            let protocolVersion = try payload.getUInt8()
                            let sessionNonce    = try payload.getBytes(5)
                            let validationKey   = try payload.getBytes(4)
                            // since this is an uint8, we cannot support 5.2. If we're here, and the version is 5, we use .v5_2
                            if protocolVersion == 5 {
                                self.bleManager.connectionState(self.handle).setConnectionProtocolVersion(.v5_2)
                            }
                            else {
                                throw BluenetError.COULD_NOT_VALIDATE_SESSION_NONCE
                            }
                            
                            self.bleManager.connectionState(self.handle).setSessionNonce(sessionNonce)
                            self.bleManager.connectionState(self.handle).setProtocolVersion(protocolVersion)
                            self.bleManager.connectionState(self.handle).validationKey(validationKey)
                            
                            seal.fulfill(())
                        }
                        catch let err {
                            seal.reject(err)
                        }
                    }
                }
            }
            .recover{(err: Error) -> Promise<Void> in
                return Promise <Void> { seal in
                    // we only want to pass this to the main promise of connect if we successfully received the nonce, but cant decrypt it.
                    if let bleErr = err as? BluenetError {
                        if bleErr == BluenetError.READ_SESSION_NONCE_ZERO_MAYBE_ENCRYPTION_DISABLED || bleErr == BluenetError.CANNOT_DO_THIS_IN_DFU_MODE {
                            seal.fulfill(())
                            return
                        }
                    }
                    seal.reject(err)
                }
            }
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
        return Promise<Void> { seal in
            let packet = ControlPacketsGenerator.getTrackedDeviceRegistrationPacket(
                trackingNumber: trackingNumber,
                locationUid: locationUid,
                profileId: profileId,
                rssiOffset: rssiOffset,
                ignoreForPresence: ignoreForPresence,
                tapToToggle: tapToToggle,
                deviceToken: deviceToken,
                ttlMinutes: ttlMinutes
            )
            
            _writePacketWithReply(bleManager: self.bleManager, handle: self.handle, packet)
                .done { resultPacket in
                    switch resultPacket.resultCode {
                    case .SUCCESS:
                        seal.fulfill(())
                    case.ERR_ALREADY_EXISTS:
                        seal.reject(BluenetError.ERR_ALREADY_EXISTS)
                    case .NO_SPACE:
                        seal.reject(BluenetError.ERR_NO_SPACE)
                    case .NO_ACCESS:
                        seal.reject(BluenetError.ERR_NO_ACCESS)
                    default:
                        LOG.error("BLUENET_LIB: registerTrackedDevice error \(resultPacket.resultCode)")
                        seal.reject(BluenetError.UNKNOWN_ERROR)
                    }
                }
                .catch{ err in seal.reject(err) }
        }
        
    }

    public func trackedDeviceHeartbeat(trackingNumber: UInt16, locationId: UInt8, deviceToken: UInt32, ttlMinutes: UInt8) -> Promise<Void> {
        return Promise<Void> { seal in
            let packet = ControlPacketsGenerator.getTrackedDeviceHeartbeatPacket(
                trackingNumber: trackingNumber,
                locationUid: locationId,
                deviceToken: deviceToken,
                ttlMinutes: ttlMinutes
            )
            
            _writePacketWithReply(bleManager: self.bleManager, handle: self.handle, packet)
                .done { resultPacket in
                    switch resultPacket.resultCode {
                    case .SUCCESS:
                        seal.fulfill(())
                    case.ERR_ALREADY_EXISTS:
                        seal.reject(BluenetError.ERR_ALREADY_EXISTS)
                    case .ERR_TIMEOUT:
                        seal.reject(BluenetError.ERR_TIMEOUT)
                    case .NO_ACCESS:
                        seal.reject(BluenetError.ERR_NO_ACCESS)
                    case .NOT_FOUND:
                        seal.reject(BluenetError.ERR_NOT_FOUND)
                    default:
                        LOG.error("BLUENET_LIB: trackedDeviceHeartbeat error \(resultPacket.resultCode)")
                        seal.reject(BluenetError.UNKNOWN_ERROR)
                    }
                }
                .catch{ err in seal.reject(err) }
        }
    }
}
