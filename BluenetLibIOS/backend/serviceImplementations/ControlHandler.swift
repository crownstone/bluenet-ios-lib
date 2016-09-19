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
    var deviceList : [String: AvailableDevice]!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings, deviceList: [String: AvailableDevice]) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
        self.deviceList = deviceList
    }
    
    public func recoverByFactoryReset(uuid: String) -> Promise<Void> {
        self.bleManager.settings.disableEncryptionTemporarily()
        return Promise<Void> { fulfill, reject in
            self.bleManager.isReady() // first check if the bluenet lib is ready before using it for BLE things.
                .then({(_) -> Promise<Void> in return self.bleManager.connect(uuid)})
                .then({(_) -> Promise<Void> in return self._recoverByFactoryReset()})
                .then({(_) -> Promise<Void> in return self._checkRecoveryProcess()})
                .then({(_) -> Promise<Void> in return self.bleManager.disconnect()})
                .then({(_) -> Promise<Void> in return self.bleManager.waitToReconnect()})
                .then({(_) -> Promise<Void> in return self.bleManager.connect(uuid)})
                .then({(_) -> Promise<Void> in return self._recoverByFactoryReset()})
                .then({(_) -> Promise<Void> in return self._checkRecoveryProcess()})
                .then({(_) -> Promise<Void> in
                    self.bleManager.settings.restoreEncryption()
                    return self.bleManager.disconnect()
                })
                .then({(_) -> Void in fulfill()})
                .error({(err) -> Void in
                    self.bleManager.settings.restoreEncryption()
                    reject(err)
                })
        }
    }

    
    func _checkRecoveryProcess() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            self.bleManager.readCharacteristic(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.FactoryReset)
                .then({(result: [UInt8]) -> Void in
                    if (result[0] == 1) {
                        fulfill()
                    }
                    else {
                        reject(BleError.NOT_IN_RECOVERY_MODE)
                    }
                })
                .error({(err) -> Void in
                    reject(BleError.CANNOT_READ_FACTORY_RESET_CHARACTERISTIC)
                })
        }
    }
    
    func _recoverByFactoryReset() -> Promise<Void> {
        let packet = Conversion.reverse(Conversion.hex_string_to_uint8_array("deadbeef"));
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.FactoryReset,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse
        )
    }
    
    public func commandFactoryReset() -> Promise<Void> {
        return self._writeControlPacket(FactoryResetPacket().getPacket())
    }
    
    
    /**
     * Switches power intelligently.
     * State has to be between 0 and 1
     */
    public func setSwitchState(state: Float) -> Promise<Void> {
        var switchState = min(1,max(0,state))*100
        
        // temporary to disable dimming
        switchState = ceil(switchState)
        
        let packet = ControlPacket(type: .SWITCH, payload8: NSNumber(float:switchState).unsignedCharValue)
        return self._writeControlPacket(packet.getPacket())
    }
    
    public func reset() -> Promise<Void> {
        print ("------ BLUENET_LIB: requesting reset")
        return self._writeControlPacket(ControlPacket(type: .RESET).getPacket())
    }
    
    public func putInDFU() -> Promise<Void> {
        print ("------ BLUENET_LIB: switching to DFU")
        return self._writeControlPacket(ControlPacket(type: .GOTO_DFU).getPacket())
    }
    
    public func disconnect() -> Promise<Void> {
        print ("------ BLUENET_LIB: REQUESTING IMMEDIATE DISCONNECT")
        return self._writeControlPacket(ControlPacket(type: .DISCONNECT).getPacket()).then({_ in self.bleManager.disconnect()})
    }
    
    /**
     * The session nonce is the only char that is ECB encrypted. We therefore read it without the libraries decryption (AES CTR) and decrypt it ourselves.
     **/
    public func getAndSetSessionNonce() -> Promise<Void> {
//        print ("------ BLUENET_LIB: Get Session Nonce")
        return self.bleManager.readCharacteristicWithoutEncryption(CSServices.CrownstoneService, characteristic: CrownstoneCharacteristics.SessionNonce)
            .then({(sessionNonce : [UInt8]) -> Promise<Void> in
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
            })
            .recover({(err: ErrorType) -> Promise<Void> in
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
            })
    }

    
    func _writeControlPacket(packet: [UInt8]) -> Promise<Void> {
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.Control,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse
        )
    }
    
}
