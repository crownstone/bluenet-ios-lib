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
        let packet = Conversion.reverse(Conversion.hex_string_to_uint8_array("deadbeef"));
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.FactoryReset,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    open func commandFactoryReset() -> Promise<Void> {
        return self._writeControlPacket(FactoryResetPacket().getPacket())
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
        var switchState = min(1,max(0,state))*100
        
        // temporary to disable dimming
        switchState = ceil(switchState)
        
        let packet = ControlPacket(type: .switch, payload8: NSNumber(value: switchState as Float).uint8Value)
        return self._writeControlPacket(packet.getPacket())
    }
    
    open func reset() -> Promise<Void> {
        print ("------ BLUENET_LIB: requesting reset")
        return self._writeControlPacket(ControlPacket(type: .reset).getPacket())
    }
    
    open func putInDFU() -> Promise<Void> {
        print ("------ BLUENET_LIB: switching to DFU")
        return self._writeControlPacket(ControlPacket(type: .goto_DFU).getPacket())
    }
    
    open func disconnect() -> Promise<Void> {
        print ("------ BLUENET_LIB: REQUESTING IMMEDIATE DISCONNECT")
        return self._writeControlPacket(ControlPacket(type: .disconnect).getPacket()).then{_ in self.bleManager.disconnect()}
    }
    
    open func keepAliveState(state: UInt8, timeout: UInt16) -> Promise<Void> {
        print ("------ BLUENET_LIB: Keep alive state")
        let keepalivePacket = keepAliveStatePacket(state: state,timeout: timeout).getPacket()
        return self._writeControlPacket(ControlPacket(type: .keep_ALIVE_STATE, payloadArray: keepalivePacket).getPacket())
    }
    
    open func keepAlive() -> Promise<Void> {
        print ("------ BLUENET_LIB: Keep alive")
        return self._writeControlPacket(ControlPacket(type: .keep_ALIVE).getPacket())
    }
    
    
    /**
     * The session nonce is the only char that is ECB encrypted. We therefore read it without the libraries decryption (AES CTR) and decrypt it ourselves.
     **/
    open func getAndSetSessionNonce() -> Promise<Void> {
//        print ("------ BLUENET_LIB: Get Session Nonce")
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
