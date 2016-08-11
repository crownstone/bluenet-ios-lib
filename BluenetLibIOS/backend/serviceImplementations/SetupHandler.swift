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
    public func setup(uuid: String) -> Promise<Void> {
        return self.bleManager.isReady()
            .then({_ in self.bleManager.connect(uuid)})
            .then({_ in self.writeCrownstoneId(12)})
            .then({_ in self.writeAdminKey("1234567890ABCDEF")})
            .then({_ in self.writeMemberKey("1234567890ABCDEF")})
            .then({_ in self.writeGuestKey("1234567890ABCDEF")})
            .then({_ in self.writeMeshAccessAddress(uuid)})
            .then({_ in self.writeIBeaconUUID("b643423e-e175-4af0-a2e4-31e32f729a8a")})
            .then({_ in self.writeIBeaconMajor(0)})
            .then({_ in self.writeIBeaconMinor(31)})
//            .then({_ in self.finalizeSetup()})
        
    }
    
    /**
     * Get the MAC address as a F3:D4:A1:CC:FF:32
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
    
    public func writeCrownstoneId(id: NSNumber) -> Promise<Void> {
        return self._writeAndVerify(.CROWNSTONE_IDENTIFIER, payload: Conversion.uint16_to_uint8_array(id.unsignedShortValue))
    }
    public func writeAdminKey(key: String) -> Promise<Void> {
        return self._writeAndVerify(.ADMIN_ENCRYPTION_KEY, payload: Conversion.string_to_uint8_array(key))
    }
    public func writeMemberKey(key: String) -> Promise<Void> {
        return self._writeAndVerify(.MEMBER_ENCRYPTION_KEY, payload: Conversion.string_to_uint8_array(key))
    }
    public func writeGuestKey(key: String) -> Promise<Void> {
        return self._writeAndVerify(.GUEST_ENCRYPTION_KEY, payload: Conversion.string_to_uint8_array(key))
    }
    public func writeMeshAccessAddress(key: String) -> Promise<Void> {
        return self._writeAndVerify(.MESH_ACCESS_ADDRESS, payload: Conversion.string_to_uint8_array(key))
    }
    public func writeIBeaconUUID(uuid: String) -> Promise<Void> {
        return self._writeAndVerify(.IBEACON_UUID, payload: Conversion.string_to_uint8_array(uuid))
    }
    public func writeIBeaconMajor(major: NSNumber) -> Promise<Void> {
        return self._writeAndVerify(.IBEACON_MAJOR, payload: Conversion.uint16_to_uint8_array(major.unsignedShortValue))
    }
    public func writeIBeaconMinor(minor: NSNumber) -> Promise<Void> {
        return self._writeAndVerify(.IBEACON_MINOR, payload: Conversion.uint16_to_uint8_array(minor.unsignedShortValue))
    }
    
    public func finalizeSetup() -> Promise<Void> {
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
        let packet = WriteConfigPacket(type: type, payloadArray: payload).getPacket()
        return _writeConfigPacket(packet)
            .then({_ -> Promise<Void> in
                let packet = ReadConfigPacket(type: .ADMIN_ENCRYPTION_KEY).getPacket()
                return self._writeConfigPacket(packet)
            })
            .then({_ -> Promise<Bool> in
                return self._verifyResult(payload)
            })
            .then({match -> Promise<Void> in
                if (match) {
                    return Promise<Void> { fulfill, reject in fulfill() }
                }
                else {
                    if (iteration > 5) {
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
            self.bleManager.readCharacteristic(CSServices.SetupService, characteristicId: SetupCharacteristics.ConfigRead,             disableEncryptionOnce: true)
                .then({data -> Void in
                    var match = data.count == target.count
                    if (match == true) {
                        for i in [Int](0...data.count-1) {
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
