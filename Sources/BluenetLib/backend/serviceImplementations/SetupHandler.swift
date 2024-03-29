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
    var handle: UUID
    
//    var unsubscribeNotificationCallback : voidPromiseCallback?
    
    var matchPacket : [UInt8] = [UInt8]()
    var validationResult : (Bool) -> Void = { _ in }
    var validationComplete = false
    var verificationFailed = false
    var step = 0
    
    init (handle: UUID, bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.handle     = handle
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    
    func handleSetupPhaseEncryption() -> Promise<Void> {
        return Promise<Void> { seal in
            self.bleManager.connectionState(self.handle).disableEncryptionTemporarily()
            self.getSessionKey()
                .then{(key: [UInt8]) -> Promise<Void> in
                    self.eventBus.emit("setupProgress", 1);
                    self.bleManager.connectionState(self.handle).loadSetupKey(key)
                    return self.getAndProcessSessionData(setupKey: key)
                }
                .done{_ -> Void in
                    self.eventBus.emit("setupProgress", 2)
                    self.bleManager.connectionState(self.handle).restoreEncryption()
                    seal.fulfill(())
                }
                .catch{(err: Error) -> Void in
                    self.bleManager.connectionState(self.handle).restoreEncryption()
                    seal.reject(err)
            }
        }
    }
    

    /**
     * This will handle the complete setup. We expect bonding has already been done by now.
     */
    public func setup(
        crownstoneId: UInt16,
        sphereId: UInt8,
        adminKey: String,
        memberKey: String,
        basicKey: String,
        localizationKey: String,
        serviceDataKey: String,
        meshNetworkKey: String,
        meshApplicationKey: String,
        meshDeviceKey: String,
        ibeaconUUID: String,
        ibeaconMajor: UInt16,
        ibeaconMinor: UInt16
        ) -> Promise<Void> {
        // if the crownstone has the new setupControl characteristic, we can do the quick setup.
        if self.bleManager.connectionState(handle).connectionProtocolVersion == .legacy {
            // do legacy setup.
            LOG.info("BLUENET_LIB: Fast Setup is NOT supported. Performing classic setup..")
            return self.legacySetup(
                crownstoneId: crownstoneId,
                adminKey: adminKey,
                memberKey: memberKey,
                guestKey: basicKey,
                meshAccessAddress: "8Ea9BEa6",
                ibeaconUUID: ibeaconUUID,
                ibeaconMajor: ibeaconMajor,
                ibeaconMinor: ibeaconMinor
            )
        }
        else if self.bleManager.connectionState(handle).connectionProtocolVersion == .v1 {
            LOG.info("BLUENET_LIB: Fast Setup is supported. Performing..")
            return self.fastSetup(
                crownstoneId: crownstoneId,
                adminKey: adminKey,
                memberKey: memberKey,
                guestKey: basicKey,
                meshAccessAddress: "8Ea9BEa6",
                ibeaconUUID: ibeaconUUID,
                ibeaconMajor: ibeaconMajor,
                ibeaconMinor: ibeaconMinor
            )
        }
        else {
            LOG.info("BLUENET_LIB: Fast Setup V3 is supported. Performing..")
            return self.fastSetupV3(
                crownstoneId: crownstoneId,
                sphereId: sphereId,
                adminKey: adminKey,
                memberKey: memberKey,
                basicKey: basicKey,
                localizationKey: localizationKey,
                serviceDataKey: serviceDataKey,
                meshNetworkKey: meshNetworkKey,
                meshApplicationKey: meshApplicationKey,
                meshDeviceKey: meshDeviceKey,
                ibeaconUUID: ibeaconUUID,
                ibeaconMajor: ibeaconMajor,
                ibeaconMinor: ibeaconMinor
            )
        }
    }
    
    /**
     * This will handle the complete setup. We expect bonding has already been done by now.
     */
    public func legacySetup(crownstoneId: UInt16, adminKey: String, memberKey: String, guestKey: String, meshAccessAddress: String, ibeaconUUID: String, ibeaconMajor: UInt16, ibeaconMinor: UInt16) -> Promise<Void> {
        self.step = 0
        self.verificationFailed = false
        return Promise<Void> { seal in
            self.setHighTX()
                .then{(_) -> Promise<Void> in return self.setupNotifications()}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 3);  return self.writeCrownstoneId(crownstoneId)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 4);  return self.writeAdminKey(adminKey)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 5);  return self.writeMemberKey(memberKey)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 6);  return self.writeGuestKey(guestKey)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 7);  return self.writeMeshAccessAddress(meshAccessAddress)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 8);  return self.writeIBeaconUUID(ibeaconUUID)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 9);  return self.writeIBeaconMajor(ibeaconMajor)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 10); return self.writeIBeaconMinor(ibeaconMinor)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 11); return self.wrapUp()}
                .done{(_) -> Void in
                    LOG.info("BLUENET_LIB: Setup Finished")
                    self.eventBus.emit("setupProgress", 13);
                    self.bleManager.connectionState(self.handle).exitSetup()
                    self.bleManager.connectionState(self.handle).restoreEncryption()
                    seal.fulfill(())
                }
                .catch{(err: Error) -> Void in
                    self.eventBus.emit("setupProgress", 0);
                    self.bleManager.connectionState(self.handle).exitSetup()
                    self.bleManager.connectionState(self.handle).restoreEncryption()
                    _ = self.bleManager.errorDisconnect(self.handle.uuidString)
                    seal.reject(err)
            }
        }
    }
    
    
    /**
     * This will handle the complete setup. We expect bonding has already been done by now.
     */
    public func fastSetupV3(
        crownstoneId: UInt16,
        sphereId: UInt8,
        adminKey: String,
        memberKey: String,
        basicKey: String,
        localizationKey: String,
        serviceDataKey: String,
        meshNetworkKey: String,
        meshApplicationKey: String,
        meshDeviceKey: String,
        ibeaconUUID: String,
        ibeaconMajor: UInt16,
        ibeaconMinor: UInt16
    ) -> Promise<Void> {
        let writeCommand = { () -> Promise<Void> in
            self.eventBus.emit("setupProgress", 6)
            return self.commandSetupV3(
                crownstoneId: crownstoneId,
                sphereId: sphereId,
                adminKey: adminKey,
                memberKey: memberKey,
                basicKey: basicKey,
                localizationKey: localizationKey,
                serviceDataKey: serviceDataKey,
                meshNetworkKey: meshNetworkKey,
                meshApplicationKey:meshApplicationKey,
                meshDeviceKey:meshDeviceKey,
                ibeaconUUID: ibeaconUUID,
                ibeaconMajor: ibeaconMajor,
                ibeaconMinor: ibeaconMinor,
                characteristicToWriteTo: getControlWriteParameters(bleManager: self.bleManager, handle: self.handle).characteristic
            )
        }
        return self._fastSetup(characteristicId: getControlReadParameters(bleManager: self.bleManager, handle: self.handle).characteristic, writeCommand: writeCommand)
    }
    
    /**
     * This will handle the complete setup. We expect bonding has already been done by now.
     */
    public func fastSetup(crownstoneId: UInt16, adminKey: String, memberKey: String, guestKey: String, meshAccessAddress: String, ibeaconUUID: String, ibeaconMajor: UInt16, ibeaconMinor: UInt16) -> Promise<Void> {
        let writeCommand = {() -> Promise<Void> in
            self.eventBus.emit("setupProgress", 6)
            return self.commandSetup(
                crownstoneId: crownstoneId,
                adminKey: adminKey,
                memberKey: memberKey,
                guestKey: guestKey,
                meshAccessAddress: meshAccessAddress,
                ibeaconUUID: ibeaconUUID,
                ibeaconMajor: ibeaconMajor,
                ibeaconMinor: ibeaconMinor
            )
        }
        return self._fastSetup(characteristicId: SetupCharacteristics.SetupControl, writeCommand: writeCommand)
    }
    
    /**
     * This will handle the complete setup. We expect bonding has already been done by now.
     */
    func _fastSetup(characteristicId: String, writeCommand: @escaping voidPromiseCallback) -> Promise<Void> {
        self.step = 0
        return Promise<Void> { seal in
            self.eventBus.emit("setupProgress", 4)
            self.bleManager.setupNotificationStream(
                self.handle,
                serviceId: CSServices.SetupService,
                characteristicId: characteristicId,
                writeCommand: writeCommand,
                resultHandler: {(returnData) -> ProcessType in
                    if let data = returnData as? [UInt8] {
                        let result = StatePacketsGenerator.getReturnPacket()
                        result.load(data)
                        if (result.valid) {
                            if (result.resultCode == ResultValue.WAIT_FOR_SUCCESS) {
                                // thats ok
                                self.eventBus.emit("setupProgress", 7)
                                return .CONTINUE
                            }
                            else if (result.resultCode == ResultValue.SUCCESS) {
                                return .FINISHED
                            }
                            else {
                                return .ABORT_ERROR
                            }
                        }
                        else {
                            // stop, something went wrong
                            return .ABORT_ERROR
                        }
                    }
                    else {
                        // stop, something went wrong
                        return .ABORT_ERROR
                    }
                },
                timeout: 5, successIfWriteSuccessful: true)
                .then{(_) -> Promise<Void> in
                    LOG.info("BLUENET_LIB: SetupCommand Finished, disconnecting")
                    self.eventBus.emit("setupProgress", 11)
                    return self.bleManager.waitForPeripheralToDisconnect(self.handle, timeout: 10)
                }
                .done{(_) -> Void in
                    LOG.info("BLUENET_LIB: Setup Finished")
                    self.eventBus.emit("setupProgress", 13)
                    self.bleManager.connectionState(self.handle).exitSetup()
                    self.bleManager.connectionState(self.handle).restoreEncryption()
                    seal.fulfill(())
                }
                .catch{(err: Error) -> Void in
                    self.eventBus.emit("setupProgress", 0)
                    self.bleManager.connectionState(self.handle).exitSetup()
                    self.bleManager.connectionState(self.handle).restoreEncryption()
                    _ = self.bleManager.errorDisconnect(self.handle.uuidString)
                    seal.reject(err)
            }
        }
    }
    
    func commandSetupV3(
        crownstoneId: UInt16,
        sphereId: UInt8,
        adminKey: String,
        memberKey: String,
        basicKey: String,
        localizationKey: String,
        serviceDataKey: String,
        meshNetworkKey: String,
        meshApplicationKey: String,
        meshDeviceKey: String,
        ibeaconUUID: String,
        ibeaconMajor: UInt16,
        ibeaconMinor: UInt16,
        characteristicToWriteTo: String
        ) -> Promise<Void> {
        let packet = ControlPacketsGenerator.getSetupPacketV3(
            crownstoneId: NSNumber(value: crownstoneId).uint8Value,
            sphereId: sphereId,
            adminKey: adminKey,
            memberKey: memberKey,
            basicKey: basicKey,
            localizationKey: localizationKey,
            serviceDataKey: serviceDataKey,
            meshNetworkKey: meshNetworkKey,
            meshApplicationKey: meshApplicationKey,
            meshDeviceKey: meshDeviceKey,
            ibeaconUUID: ibeaconUUID,
            ibeaconMajor: ibeaconMajor,
            ibeaconMinor: ibeaconMinor
        )
        return self.bleManager.writeToCharacteristic(
            self.handle,
            serviceId: CSServices.SetupService,
            characteristicId: characteristicToWriteTo,
            data: Data(bytes: packet, count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    func commandSetup(crownstoneId: UInt16, adminKey: String, memberKey: String, guestKey: String, meshAccessAddress: String, ibeaconUUID: String, ibeaconMajor: UInt16, ibeaconMinor: UInt16) -> Promise<Void> {
        let packet = ControlPacketsGenerator.getSetupPacket(
            type: 0,
            crownstoneId: NSNumber(value: crownstoneId).uint8Value,
            adminKey: adminKey,
            memberKey: memberKey,
            guestKey: guestKey,
            meshAccessAddress: meshAccessAddress,
            ibeaconUUID: ibeaconUUID,
            ibeaconMajor: ibeaconMajor,
            ibeaconMinor: ibeaconMinor
        )
        return self.bleManager.writeToCharacteristic(
            self.handle,
            serviceId: CSServices.SetupService,
            characteristicId: SetupCharacteristics.SetupControl,
            data: Data(bytes: packet, count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    func wrapUp() -> Promise<Void> {
        return self.finalizeSetup()
            .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 12); return self.bleManager.disconnect(self.handle.uuidString)}
    }
    
    public func getSessionKey() -> Promise<[UInt8]> {
        LOG.info("getSessionKey")
        return self.bleManager.readCharacteristicWithoutEncryption(self.handle, service: CSServices.SetupService, characteristic: SetupCharacteristics.SessionKey)
    }
        
    public func getAndProcessSessionData(setupKey : [UInt8]) -> Promise<Void> {
        LOG.info("processSessionNone")
        let sessionParameters = getSessionNonceReadParameters(bleManager: self.bleManager, handle: self.handle)
              
        return self.bleManager.readCharacteristicWithoutEncryption(self.handle, service: sessionParameters.service, characteristic: sessionParameters.characteristic)
            .then{ (sessionData : [UInt8]) -> Promise<Void> in
                return Promise <Void> { seal in
                    do {
                        try EncryptionHandler.processSessionData(sessionData, key: setupKey, connectionState: self.bleManager.connectionState(self.handle))
                        seal.fulfill(())
                    }
                    catch let err {
                        seal.reject(err)
                    }
                }
            }
    }
    
    
    /**
     * Get the MAC address as a F3:D4:A1:CC:FF:32 String
     */
    public func getMACAddress() -> Promise<String> {
        return Promise<String> { seal in
            self.bleManager.readCharacteristicWithoutEncryption(self.handle, service: CSServices.SetupService, characteristic: SetupCharacteristics.MacAddress)
                .done{data -> Void in LOG.info("\(data)"); seal.fulfill(Conversion.uint8_array_to_macAddress(data))}
                .catch{err in seal.reject(err)}
        }
    }
    
    
    
    
    
    func setupNotifications() -> Promise<Void> {
        // use the notification merger to handle the full packet once we have received it.
        let merger = NotificationMerger(callback: { data -> Void in
            do {
                // attempt to decrypt it
                let decryptedData = try EncryptionHandler.decrypt(Data(data), connectionState: self.bleManager.connectionState(self.handle))
                
                if (self._checkMatch(input: decryptedData.bytes, target: self.matchPacket)) {
                    self.matchPacket = []
                    self.validationComplete = true
                    self.validationResult(true)
                }
                else {
                    self.matchPacket = []
                    self.validationComplete = true
                    self.validationResult(false)
                }
            }
            catch _ {
                self.matchPacket = []
                self.validationComplete = true
                self.validationResult(false)
            }
        })
        
        let notificationCallback = {(data: Any) -> Void in
            if let castData = data as? Data {
                merger.merge(castData.bytes)
            }
        }
        
        
        return self.bleManager.enableNotifications(
            self.handle,
            serviceId: CSServices.SetupService,
            characteristicId: SetupCharacteristics.ConfigRead,
            callback: notificationCallback
        )
    }
    
    // MARK : Support functions
    
    func _writeAndVerify(_ type: ConfigurationType, payload: [UInt8], iteration: UInt8 = 0) -> Promise<Void> {
        self.step += 1
        let initialPacket = WriteConfigPacket(type: type, payloadArray: payload).getPacket()
        return self._writeSetupConfigPacket(initialPacket)
            .then{_ -> Promise<Void> in
                return self.bleManager.waitToWrite()
            }
            .then{_ -> Promise<Void> in
                if (self.verificationFailed == true) {
                    return self.bleManager.waitToWrite()
                }
                else {
                    return Promise<Void> { seal in seal.fulfill(()) }
                }
            }
            .then{_ -> Promise<Bool> in
                let packet = ReadConfigPacket(type: type).getPacket()
                // Make sure we first provide the fulfillment function before we ask for the notifications.
                return Promise<Bool> { seal in
                    self.matchPacket = initialPacket
                    self.validationResult = seal.fulfill
                    self.validationComplete = false
                    let stepId = self.step
                    
                    // fallback delay to cancel the wait for incoming notifications.
                    delay(4*timeoutDurations.waitForWrite, {
                        if (self.validationComplete == false && self.step == stepId) {
                            self.validationResult = { _ in }
                            self.matchPacket = []
                            seal.fulfill(false)
                        }
                    })
                    
                    self._writeSetupConfigPacket(packet).catch{ err in seal.reject(err) }
                }
            }
            .then{ match -> Promise<Void> in
                if (match) {
                    return Promise<Void> { seal in seal.fulfill(()) }
                }
                else {
                    self.verificationFailed = true
                    if (iteration > 2) {
                        return Promise<Void> { seal in seal.reject(BluenetError.CANNOT_WRITE_AND_VERIFY) }
                    }
                    return self._writeAndVerify(type, payload:payload, iteration: iteration+1)
                }
        }
    }
    
    
    func _checkMatch(input: [UInt8], target: [UInt8]) -> Bool {
        let prefixLength = 4
        let dataLength = Int(Conversion.uint8_array_to_uint16([input[2],input[3]]))
        var match = (input.count >= (prefixLength + dataLength) && target.count >= (prefixLength + dataLength))
        if (match == true) {
            for i in [Int](0..<dataLength) {
                if (input[i+prefixLength] != target[i+prefixLength]) {
                    match = false
                }
            }
        }
        return match
    }
    
    
    // MARK: LEGACY FUNCTIONS FOR BEFORE VERSION 3
    /**
     * This will handle the factory reset during setup mode.
     */
    public func factoryReset() -> Promise<Void> {
        return self._factoryReset()
            .done{ (_) -> Void in _ = self.bleManager.disconnect(self.handle.uuidString) }
    }
    
    
    public func _factoryReset() -> Promise<Void> {
        LOG.info("factoryReset in setup")
        let packet = ControlPacket(type: .factory_RESET).getPacket()
        return _writeControlPacket(bleManager: self.bleManager, self.handle, packet)
    }
    
    public func setHighTX() -> Promise<Void> {
        LOG.info("setHighTX")
        let packet = ControlPacket(type: .increase_TX).getPacket()
        return _writeControlPacket(bleManager: self.bleManager, self.handle, packet)
    }
    public func writeCrownstoneId(_ id: UInt16) -> Promise<Void> {
        LOG.info("writeCrownstoneId")
        return self._writeAndVerify(.crownstone_IDENTIFIER, payload: Conversion.uint16_to_uint8_array(id))
    }
    public func writeAdminKey(_ key: String) -> Promise<Void> {
        LOG.info("writeAdminKey")
        return self._writeAndVerify(.admin_ENCRYPTION_KEY, payload: Conversion.ascii_or_hex_string_to_16_byte_array(key))
    }
    public func writeMemberKey(_ key: String) -> Promise<Void> {
        LOG.info("writeMemberKey")
        return self._writeAndVerify(.member_ENCRYPTION_KEY, payload: Conversion.ascii_or_hex_string_to_16_byte_array(key))
    }
    public func writeGuestKey(_ key: String) -> Promise<Void> {
        LOG.info("writeGuestKey")
        return self._writeAndVerify(.guest_ENCRYPTION_KEY, payload: Conversion.ascii_or_hex_string_to_16_byte_array(key))
    }
    public func writeMeshAccessAddress(_ address: String) -> Promise<Void> {
        LOG.info("writeMeshAccessAddress")
        return self._writeAndVerify(.mesh_ACCESS_ADDRESS, payload: Conversion.hex_string_to_uint8_array(address))
    }
    public func writeIBeaconUUID(_ uuid: String) -> Promise<Void> {
        LOG.info("writeIBeaconUUID")
        return self._writeAndVerify(.ibeacon_UUID, payload: Conversion.ibeaconUUIDString_to_reversed_uint8_array(uuid))
    }
    public func writeIBeaconMajor(_ major: UInt16) -> Promise<Void> {
        LOG.info("writeIBeaconMajor")
        return self._writeAndVerify(.ibeacon_MAJOR, payload: Conversion.uint16_to_uint8_array(major))
    }
    public func writeIBeaconMinor(_ minor: UInt16) -> Promise<Void> {
        LOG.info("writeIBeaconMinor")
        return self._writeAndVerify(.ibeacon_MINOR, payload: Conversion.uint16_to_uint8_array(minor))
    }
    public func finalizeSetup() -> Promise<Void> {
        LOG.info("finalizeSetup")
        let packet = ControlPacket(type: .validate_SETUP).getPacket()
        return _writeControlPacket(bleManager: self.bleManager, self.handle, packet)
    }
    func _writeSetupConfigPacket(_ packet: [UInt8]) -> Promise<Void> {
        return self.bleManager.writeToCharacteristic(
            self.handle,
            serviceId: CSServices.SetupService,
            characteristicId: SetupCharacteristics.ConfigControl,
            data: Data(bytes: packet, count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
}
