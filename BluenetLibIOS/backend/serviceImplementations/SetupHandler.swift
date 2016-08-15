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
        return self.writeCrownstoneId(crownstoneId)
            .then({(_) -> Promise<Void> in return self.writeAdminKey(adminKey)})
            .then({(_) -> Promise<Void> in return self.writeMemberKey(memberKey)})
            .then({(_) -> Promise<Void> in return self.writeGuestKey(guestKey)})
            .then({(_) -> Promise<Void> in return self.writeMeshAccessAddress(meshAccessAddress)})
            .then({(_) -> Promise<Void> in return self.writeIBeaconUUID(ibeaconUUID)})
            .then({(_) -> Promise<Void> in return self.writeIBeaconMajor(ibeaconMajor)})
            .then({(_) -> Promise<Void> in return self.writeIBeaconMinor(ibeaconMinor)})
            .then({(_) -> Promise<Void> in return self.finalizeSetup()})
    }
    
    /**
     * Get the MAC address as a F3:D4:A1:CC:FF:32 String
     */
    public func getMACAddress() -> Promise<String> {
        return Promise<String> { fulfill, reject in
            self.bleManager.readCharacteristicWithBonding(CSServices.SetupService, characteristicId: SetupCharacteristics.MacAddress, disableEncryptionOnce: true)
                .then({data -> Void in
                    var string = ""
                    for i in [Int](0...data.count-1) {
                        // due to little endian, we read it out in the reverse order.
                        string +=  Conversion.uint8_to_hex_string(data[data.count-1-i])
                        
                        // add colons to the string
                        if (i < data.count-1) {
                            string += ":"
                        }
                    }
                    fulfill(string)
                })
                .error({(error: ErrorType) -> Void in reject(error)})
        }
    }
    
    public func writeCrownstoneId(id: UInt16) -> Promise<Void> {
        print ("writing ID")
        return self._writeAndVerify(.CROWNSTONE_IDENTIFIER, payload: Conversion.uint16_to_uint8_array(id))
    }
    public func writeAdminKey(key: String) -> Promise<Void> {
        print ("writing writeAdminKey")
        return self._writeAndVerify(.ADMIN_ENCRYPTION_KEY, payload: Conversion.string_to_uint8_array(key))
    }
    public func writeMemberKey(key: String) -> Promise<Void> {
        print ("writing writeMemberKey")
        return self._writeAndVerify(.MEMBER_ENCRYPTION_KEY, payload: Conversion.string_to_uint8_array(key))
    }
    public func writeGuestKey(key: String) -> Promise<Void> {
        print ("writing writeGuestKey")
        return self._writeAndVerify(.GUEST_ENCRYPTION_KEY, payload: Conversion.string_to_uint8_array(key))
    }
    public func writeMeshAccessAddress(address: UInt32) -> Promise<Void> {
        print ("writing writeMeshAccessAddress")
        return self._writeAndVerify(.MESH_ACCESS_ADDRESS, payload: Conversion.uint32_to_uint8_array(address))
    }
    public func writeIBeaconUUID(uuid: String) -> Promise<Void> {
        print ("writing writeIBeaconUUID")
        return self._writeAndVerify(.IBEACON_UUID, payload: Conversion.ibeaconUUIDString_to_uint8_array(uuid))
    }
    public func writeIBeaconMajor(major: UInt16) -> Promise<Void> {
        print ("writing ID")
        return self._writeAndVerify(.IBEACON_MAJOR, payload: Conversion.uint16_to_uint8_array(major))
    }
    public func writeIBeaconMinor(minor: UInt16) -> Promise<Void> {
        print ("writing writeIBeaconMinor")
        return self._writeAndVerify(.IBEACON_MINOR, payload: Conversion.uint16_to_uint8_array(minor))
    }
    
    public func finalizeSetup() -> Promise<Void> {
        print ("writing finalizeSetup")
        let packet = ControlPacket(type: .VALIDATE_SETUP).getPacket()
        return self.bleManager.writeToCharacteristic(
            CSServices.SetupService,
            characteristicId: SetupCharacteristics.Control,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse,
            disableEncryptionOnce: true
        )
    }
    public func factoryReset() -> Promise<Void> {
        let packet = FactoryResetPacket().getPacket()
        return self.bleManager.writeToCharacteristic(
            CSServices.SetupService,
            characteristicId: SetupCharacteristics.Control,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse,
            disableEncryptionOnce: true
        )
    }
    
    
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
                    print ("verified!")
                    return Promise<Void> { fulfill, reject in fulfill() }
                }
                else {
                    if (iteration > 1) {
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
            type: CBCharacteristicWriteType.WithResponse,
            disableEncryptionOnce: true
        )
    }
    
    func _verifyResult(target: [UInt8]) -> Promise<Bool> {
        return Promise<Bool> { fulfill, reject in
            self.bleManager.readCharacteristic(CSServices.SetupService, characteristicId: SetupCharacteristics.ConfigRead, disableEncryptionOnce: true)
                .then({data -> Void in
                    var match = data.count == target.count
                    var prefixLength = 4
                    if (match == true && data.count > prefixLength) {
                        for i in [Int](prefixLength...data.count-1) {
                            if (data[i] != target[i]){
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
