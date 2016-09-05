//
//  SetupHandler.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

public class SetupHandler {
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
    
    /**
     * This will handle the complete setup. We expect bonding has already been done by now.
     */
    public func setup(crownstoneId: UInt16, adminKey: String, memberKey: String, guestKey: String, meshAccessAddress: UInt32, ibeaconUUID: String, ibeaconMajor: UInt16, ibeaconMinor: UInt16) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            self.bleManager.settings.disableEncryptionTemporarily()
            self.getSessionKey()
                .then({(key: [UInt8]) -> Promise<[UInt8]> in
                    self.bleManager.settings.loadSetupKey(key)
                    return self.getSessionNonce()
                })
                .then({(nonce: [UInt8]) ->  Void in
                    self.bleManager.settings.setSessionNonce(nonce)
                    self.bleManager.settings.restoreEncryption()
                    
                })
                .then({(_) -> Promise<Void> in return self.writeCrownstoneId(crownstoneId)})
                .then({(_) -> Promise<Void> in return self.writeAdminKey(adminKey)})
                .then({(_) -> Promise<Void> in return self.writeMemberKey(memberKey)})
                .then({(_) -> Promise<Void> in return self.writeGuestKey(guestKey)})
                .then({(_) -> Promise<Void> in return self.writeMeshAccessAddress(meshAccessAddress)})
                .then({(_) -> Promise<Void> in return self.writeIBeaconUUID(ibeaconUUID)})
                .then({(_) -> Promise<Void> in return self.writeIBeaconMajor(ibeaconMajor)})
                .then({(_) -> Promise<Void> in return self.writeIBeaconMinor(ibeaconMinor)})
                .then({(_) -> Promise<Void> in return self.finalizeSetup()})
                .then({(_) -> Promise<Void> in return self.bleManager.disconnect()})
                .then({(_) -> Void in
                    print("------ BLUENET_LIB: Setup Finished")
                    self.bleManager.settings.exitSetup()
                    fulfill()
                })
                .error({(err: ErrorType) -> Void in
                    self.bleManager.settings.exitSetup()
                    self.bleManager.disconnect()
                    reject(err)
                })
        }
    }
    
    public func getSessionKey() -> Promise<[UInt8]> {
        print ("getSessionKey")
        return self.bleManager.readCharacteristicWithoutEncryption(CSServices.SetupService, characteristic: SetupCharacteristics.SessionKey)
    }
        
    public func getSessionNonce() -> Promise<[UInt8]> {
        print ("getSessionNonce")
        return self.bleManager.readCharacteristicWithoutEncryption(CSServices.SetupService, characteristic: SetupCharacteristics.SessionNonce)
    }
    
    /**
     * Get the MAC address as a F3:D4:A1:CC:FF:32 String
     */
    public func getMACAddress() -> Promise<String> {
        return Promise<String> { fulfill, reject in
            self.bleManager.readCharacteristicWithoutEncryption(CSServices.SetupService, characteristic: SetupCharacteristics.MacAddress)
                .then({data -> Void in print(data); fulfill(Conversion.uint8_array_to_macAddress(data))})
                .error(reject)
        }
    }
    
    public func writeCrownstoneId(id: UInt16) -> Promise<Void> {
        print ("writeCrownstoneId")
        return self._writeAndVerify(.CROWNSTONE_IDENTIFIER, payload: Conversion.uint16_to_uint8_array(id))
    }
    public func writeAdminKey(key: String) -> Promise<Void> {
        print ("writeAdminKey")
        return self._writeAndVerify(.ADMIN_ENCRYPTION_KEY, payload: Conversion.hex_string_to_uint8_array(key))
    }
    public func writeMemberKey(key: String) -> Promise<Void> {
        print ("writeMemberKey")
        return self._writeAndVerify(.MEMBER_ENCRYPTION_KEY, payload: Conversion.hex_string_to_uint8_array(key))
    }
    public func writeGuestKey(key: String) -> Promise<Void> {
        print ("writeGuestKey")
        return self._writeAndVerify(.GUEST_ENCRYPTION_KEY, payload: Conversion.hex_string_to_uint8_array(key))
    }
    public func writeMeshAccessAddress(address: UInt32) -> Promise<Void> {
        print ("writeMeshAccessAddress")
        return self._writeAndVerify(.MESH_ACCESS_ADDRESS, payload: Conversion.uint32_to_uint8_array(address))
    }
    public func writeIBeaconUUID(uuid: String) -> Promise<Void> {
        print ("writeIBeaconUUID")
        return self._writeAndVerify(.IBEACON_UUID, payload: Conversion.ibeaconUUIDString_to_reversed_uint8_array(uuid))
    }
    public func writeIBeaconMajor(major: UInt16) -> Promise<Void> {
        print ("writeIBeaconMajor")
        return self._writeAndVerify(.IBEACON_MAJOR, payload: Conversion.uint16_to_uint8_array(major))
    }
    public func writeIBeaconMinor(minor: UInt16) -> Promise<Void> {
        print ("writeIBeaconMinor")
        return self._writeAndVerify(.IBEACON_MINOR, payload: Conversion.uint16_to_uint8_array(minor))
    }
    public func finalizeSetup() -> Promise<Void> {
        print ("finalizeSetup")
        let packet = ControlPacket(type: .VALIDATE_SETUP).getPacket()
        return self.bleManager.writeToCharacteristic(
            CSServices.SetupService,
            characteristicId: SetupCharacteristics.Control,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse
        )
    }
    
    // MARK : Support functions
    
    func _writeAndVerify(type: ConfigurationType, payload: [UInt8], iteration: UInt8 = 0) -> Promise<Void> {
        let initialPacket = WriteConfigPacket(type: type, payloadArray: payload).getPacket()
        return _writeConfigPacket(initialPacket)
            .then({_ -> Promise<Void> in self.bleManager.waitToWrite()})
            .then({_ -> Promise<Void> in
                let packet = ReadConfigPacket(type: type).getPacket()
                return self._writeConfigPacket(packet)
            })
            .then({_ -> Promise<Void> in self.bleManager.waitToWrite()})
            .then({_ -> Promise<Bool> in
                return self._verifyResult(initialPacket)
            })
            .then({match -> Promise<Void> in
                if (match) {
                    return Promise<Void> { fulfill, reject in fulfill() }
                }
                else {
                    if (iteration > 2) {
                        return Promise<Void> { fulfill, reject in reject(BleError.CANNOT_WRITE_AND_VERIFY) }
                    }
                    return self._writeAndVerify(type, payload:payload, iteration: iteration+1)
                }
            })
    }
    
    func _writeConfigPacket(packet: [UInt8]) -> Promise<Void> {
        return self.bleManager.writeToCharacteristic(
            CSServices.SetupService,
            characteristicId: SetupCharacteristics.ConfigControl,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse
        )
    }
    
    func _verifyResult(target: [UInt8]) -> Promise<Bool> {
        return Promise<Bool> { fulfill, reject in
            self.bleManager.readCharacteristic(CSServices.SetupService, characteristicId: SetupCharacteristics.ConfigRead)
                .then({data -> Void in
                    let prefixLength = 4
                    let dataLength = Int(Conversion.uint8_array_to_uint16([data[2],data[3]]))
                    var match = (data.count >= prefixLength + dataLength && target.count >= prefixLength + dataLength)
                    if (match == true) {
                        for i in [Int](0...dataLength-1) {
                            if (data[i+prefixLength] != target[i+prefixLength]){
                                match = false
                            }
                        }
                    }
                    fulfill(match)
                })
                .error({(error: ErrorType) -> Void in reject(error)})
        }
    }
    
    

}
