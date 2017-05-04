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

open class ControlHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    var deviceList : [String: AvailableDevice]!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings, deviceList: [String: AvailableDevice]) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
        self.deviceList = deviceList
    }
    
    open func recoverByFactoryReset(_ uuid: String) -> Promise<Void> {
        self.bleManager.settings.disableEncryptionTemporarily()
        return Promise<Void> { fulfill, reject in
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
                    self.bleManager.settings.restoreEncryption()
                    return self.bleManager.disconnect()
                }
                .then {(_) -> Void in fulfill()}
                .catch {(err) -> Void in
                    self.bleManager.settings.restoreEncryption()
                    self.bleManager.disconnect().then{_ in reject(err)}.catch{_ in reject(err)}
                }
        }
    }

    
    func _checkRecoveryProcess() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            self.bleManager.readCharacteristic(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.FactoryReset)
                .then{(result: [UInt8]) -> Void in
                    if (result[0] == 1) {
                        fulfill()
                    }
                    else if (result[0] == 2) {
                        reject(BleError.RECOVER_MODE_DISABLED)
                    }
                    else {
                        reject(BleError.NOT_IN_RECOVERY_MODE)
                    }
                }
                .catch{(err) -> Void in
                    reject(BleError.CANNOT_READ_FACTORY_RESET_CHARACTERISTIC)
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
    
    open func commandFactoryReset() -> Promise<Void> {
        return self._writeControlPacket(ControlPacketsGenerator.getCommandFactoryResetPacket())
            .then{(_) -> Promise<[UInt8]> in return self._readControlPacket()}
            .then{(response: [UInt8]) -> Promise<Void> in
                return Promise<Void> {fulfill, reject in
                    if (response[0] == 0) {
                        fulfill()
                    }
                    else {
                        reject(BleError.COULD_NOT_FACTORY_RESET)
                    }
                }
            }
    }
    
    
    /**
     * Switches power intelligently.
     * State has to be between 0 and 1
     */
    open func setSwitchState(_ state: Float) -> Promise<Void> {
        let packet = ControlPacketsGenerator.getSwitchStatePacket(state)
        return self._writeControlPacket(packet)
    }
    
    open func reset() -> Promise<Void> {
        LOG.info("BLUENET_LIB: requesting reset")
        return self._writeControlPacket(ControlPacketsGenerator.getResetPacket())
    }
    
    open func putInDFU() -> Promise<Void> {
        LOG.info("BLUENET_LIB: switching to DFU")
        return self._writeControlPacket(ControlPacketsGenerator.getPutInDFUPacket())
    }
    
    open func disconnect() -> Promise<Void> {
        LOG.info("BLUENET_LIB: REQUESTING IMMEDIATE DISCONNECT")
        return self._writeControlPacket(ControlPacketsGenerator.getDisconnectPacket()).then{_ in self.bleManager.disconnect()}
    }
    
    open func switchRelay(_ state: UInt8) -> Promise<Void> {
        LOG.info("BLUENET_LIB: switching relay to \(state)")
        return self._writeControlPacket(ControlPacketsGenerator.getRelaySwitchPacket(state))
    }
    
    
    /**
     * This method will ask the current switch state and listen to the notification response. 
     * It will then switch the crownstone. If it was > 0 --> 0 if it was 0 --> 1.
     **/
    open func toggleSwitchState() -> Promise<Float> {
        return Promise<Float> { fulfill, reject in
            var newSwitchStateSend : Float = 0
            let writeCommand : voidPromiseCallback = { _ in
                return self.bleManager.writeToCharacteristic(
                    CSServices.CrownstoneService,
                    characteristicId: CrownstoneCharacteristics.StateControl,
                    data: NotificationStatePacket(type: .switch_STATE).getNSData(),
                    type: CBCharacteristicWriteType.withResponse);
            }
            self.bleManager.setupSingleNotification(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.StateRead, writeCommand: writeCommand)
                .then{ data -> Promise<Void> in
                    let currentSwitchState = data[4];
                    var newSwitchState : Float = 0;
                    if (currentSwitchState == 0) {
                        newSwitchState = 1.0
                    }
                    newSwitchStateSend = newSwitchState
                    return self.setSwitchState(newSwitchState)
                }
                .then{ _ in fulfill(newSwitchStateSend) }
                .catch{ err in reject(err) }
        }
    }
    
    open func switchPWM(_ state: Float) -> Promise<Void> {
        LOG.info("BLUENET_LIB: switching PWM to \(state)")
        return self._writeControlPacket(ControlPacketsGenerator.getPwmSwitchPacket(state))
    }

    
    /**
     * If the changeState is true, then the state and timeout will be used. If it is false, the keepaliveState on the Crownstone will be cleared and nothing will happen when the timer runs out.
     */
    open func keepAliveState(changeState: Bool, state: Float, timeout: UInt16) -> Promise<Void> {
        return self._writeControlPacket(ControlPacketsGenerator.getKeepAliveStatePacket(changeState: changeState, state: state, timeout: timeout))
    }
    
    open func keepAlive() -> Promise<Void> {
        LOG.info("BLUENET_LIB: Keep alive")
        return self._writeControlPacket(ControlPacketsGenerator.getKeepAlivePacket())
    }
    
    
    /**
     * The session nonce is the only char that is ECB encrypted. We therefore read it without the libraries decryption (AES CTR) and decrypt it ourselves.
     **/
    open func getAndSetSessionNonce() -> Promise<Void> {
        LOG.verbose("BLUENET_LIB: Get Session Nonce")
        return self.bleManager.readCharacteristicWithoutEncryption(CSServices.CrownstoneService, characteristic: CrownstoneCharacteristics.SessionNonce)
            .then{(sessionNonce : [UInt8]) -> Promise<Void> in
                return Promise <Void> { fulfill, reject in
                    do {
                        let sessionNonce = try EncryptionHandler.decryptSessionNonce(sessionNonce, key: self.bleManager.settings.guestKey!)
                        self.bleManager.settings.setSessionNonce(sessionNonce)
                        fulfill()
                    }
                    catch let err {
                        reject(err)
                    }
                }
            }
            .recover{(err: Error) -> Promise<Void> in
                return Promise <Void> { fulfill, reject in
                    // we only want to pass this to the main promise of connect if we successfully received the nonce, but cant decrypt it.
                    if let bleErr = err as? BleError {
                        if bleErr == BleError.COULD_NOT_VALIDATE_SESSION_NONCE {
                            reject(err)
                            return
                        }
                    }
                    fulfill()
                }
            }
    }

    
    func _writeControlPacket(_ packet: [UInt8]) -> Promise<Void> {
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.Control,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    
    func _readControlPacket() -> Promise<[UInt8]> {
        return self.bleManager.readCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.Control
        )
    }
    
}
