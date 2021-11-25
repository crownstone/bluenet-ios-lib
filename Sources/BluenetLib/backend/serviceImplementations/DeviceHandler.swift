//
//  DfuHandler.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth


public class DeviceHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!    
    let handle : UUID
    
    init (handle: UUID, bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.handle     = handle
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    public func getFirmwareRevision() -> Promise<String> {
        return getSoftwareRevision()
    }
    
    
    /**
     * Returns a symvar version number like  "1.1.0"
     */
    public func getSoftwareRevision() -> Promise<String> {
        return self.bleManager.readCharacteristicWithoutEncryption(self.handle, service: CSServices.DeviceInformation, characteristic: DeviceCharacteristics.FirmwareRevision)
            .then{ data -> Promise<String> in
                return Promise<String>{seal in seal.fulfill(Conversion.uint8_array_to_string(data))
            }}
    }
    
    /**
     * Returns a symvar version number like "1.4.0"
     */
    public func getBootloaderRevisionInAppMode() -> Promise<String> {
        return Promise<String> { seal in seal.fulfill("") }
    }
    
    /**
     * Returns a hardware version:
     *  hardwareVersion + productionRun + housingId + reserved + nordicChipVersion
     *
     *  hardwareVersion:
     *  ----------------------
     *  | GENERAL | PCB      |
     *  | PRODUCT | VERSION  |
     *  | INFO    |          |
     *  ----------------------
     *  | 1 01 02 | 00 92 00 |
     *  ----------------------
     *  |  |  |    |  |  |---  Patch number of PCB version
     *  |  |  |    |  |------  Minor number of PCB version
     *  |  |  |    |---------  Major number of PCB version
     *  |  |  |--------------  Product Type: 1 Dev, 2 Plug, 3 Builtin, 4 Guidestone
     *  |  |-----------------  Market: 1 EU, 2 US
     *  |--------------------  Family: 1 Crownstone
     *
     * productionRun = "0000"         (4)
     * housingId = "0000"             (4)
     * reserved = "00000000"          (8)
     * nordicChipVersion = "xxxxxx"   (6)
     */
    public func getHardwareRevision() -> Promise<String> {
        return self.bleManager.readCharacteristicWithoutEncryption(self.handle, service: CSServices.DeviceInformation, characteristic: DeviceCharacteristics.HardwareRevision)
            .then{ data -> Promise<String> in
                return Promise<String>{seal in seal.fulfill(Conversion.uint8_array_to_string(data))
            }}
    }
    
    
    
    
    
    public func getUICRData() -> Promise<[String: Any]> {
        let writeCommand : voidPromiseCallback = {
            return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getControlPacket(type: .GET_UICR_DATA).getPacket())
        }
        return _writePacketWithReply(bleManager: self.bleManager, handle: self.handle, writeCommand: writeCommand)
            .then{ resultPacket -> Promise<[String: Any]> in
                return Promise<[String: Any]> { seal in
                    do {
                        let payload = DataStepper(resultPacket.payload)
                        let returnDict : [String: Any] = [
                            "board"          : try payload.getUInt32(),
                            "productType"    : try payload.getUInt8(),
                            "region"         : try payload.getUInt8(),
                            "productFamily"  : try payload.getUInt8(),
                            "reserved1"      : try payload.getUInt8(),
                             
                            "hardwarePatch"  : try payload.getUInt8(),
                            "hardwareMinor"  : try payload.getUInt8(),
                            "hardwareMajor"  : try payload.getUInt8(),
                            "reserved2"      : try payload.getUInt8(),
                             
                            "productHousing" : try payload.getUInt8(),
                            "productionWeek" : try payload.getUInt8(),
                            "productionYear" : try payload.getUInt8(),
                            "reserved3"      : try payload.getUInt8(),
                        ]
                                                        
                        seal.fulfill(returnDict)
                    }
                    catch {
                        seal.reject(BluenetError.INVALID_DATA)
                    }
                }
            }
    }
    
    
    public func getBootloaderRevision() -> Promise<String> {
        if self.bleManager.connectionState(handle).operationMode != .dfu {
            switch (self.bleManager.connectionState(handle).connectionProtocolVersion) {
                case .unknown, .legacy, .v1, .v2, .v3:
                    return self.getBootloaderRevisionInAppMode()
                case .v5:
                    let writeCommand : voidPromiseCallback = {
                        return _writeControlPacket(bleManager: self.bleManager, self.handle, ControlPacketsGenerator.getControlPacket(type: .GET_BOOTLOADER_VERSION).getPacket())
                    }
                    return _writePacketWithReply(bleManager: self.bleManager, handle: self.handle, writeCommand: writeCommand)
                        .then{ resultPacket -> Promise<String> in
                            return Promise<String> { seal in
                                do {
                                    let payload = DataStepper(resultPacket.payload)
                                    let packetProtocolVersion = try payload.getUInt8()
                                    let dfuVersion  = try payload.getUInt16()
                                    let major       = try payload.getUInt8()
                                    let minor       = try payload.getUInt8()
                                    let patch       = try payload.getUInt8()
                                    let prerelease  = try payload.getUInt8()
                                    let buildType   = try payload.getUInt8()
                                    
                                    if (prerelease == 255) {
                                        seal.fulfill("\(major).\(minor).\(patch)")
                                    }
                                    else {
                                        seal.fulfill("\(major).\(minor).\(patch)-RC\(prerelease)")
                                    }
                                }
                                catch {
                                    seal.fulfill("")
                                }
                            }
                        }
            }
        }
        else {
            return self.getSoftwareRevision()
        }
    }

    
}
