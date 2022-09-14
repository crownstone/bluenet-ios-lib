//
//  StatePackets.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 29/10/2019.
//  Copyright © 2019 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth



public class StatePacketsGeneratorClass {
    var connectionProtocolVersion : ConnectionProtocolVersion = .v1
    
    init() {}
    
    func getWritePacket(type: ConfigurationType) -> BLEPacketBase {
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                return WriteConfigPacket(type: type)
            case .v3:
                return ControlStateSetPacket(  type: StateTypeV3(rawValue: UInt16(type.rawValue))!)
            case .v5, .v5_2:
                return ControlStateSetPacketV5(type: StateTypeV3(rawValue: UInt16(type.rawValue))!)
        }
    }
    func getWritePacket(type: StateType) -> BLEPacketBase {
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                 return WriteStatePacket(type: type)
            case .v3:
                return ControlStateSetPacket(type: StateTypeV3(rawValue: UInt16(type.rawValue))!)
            case .v5, .v5_2:
                return ControlStateSetPacketV5(type: StateTypeV3(rawValue: UInt16(type.rawValue))!)
        }
    }
    func getWritePacket(type: StateTypeV3, id: UInt16 = 0, persistenceMode: SetPersistenceMode = .STORED) -> BLEPacketBase {
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2, .v3:
                return ControlStateSetPacket(type: type)
            case .v5, .v5_2:
                return ControlStateSetPacketV5(type: type, id: id, persistence: persistenceMode)
        }
    }
    
    func getReadPacket(type: ConfigurationType) -> BLEPacketBase {
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                return ReadConfigPacket(type: type)
            case .v3:
                return ControlStateGetPacket(  type: StateTypeV3(rawValue: UInt16(type.rawValue))!)
            case .v5, .v5_2:
                return ControlStateGetPacketV5(type: StateTypeV3(rawValue: UInt16(type.rawValue))!)
        }
    }
    func getReadPacket(type: StateType) -> BLEPacketBase {
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                return ReadStatePacket(type: type)
            case .v3:
                return ControlStateGetPacket(  type: StateTypeV3(rawValue: UInt16(type.rawValue))!)
            case .v5, .v5_2:
                return ControlStateGetPacketV5(type: StateTypeV3(rawValue: UInt16(type.rawValue))!)
        }
    }
    func getReadPacket(type: StateTypeV3, id: UInt16 = 0, persistenceMode: GetPersistenceMode = .CURRENT) -> BLEPacketBase {
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                return ControlStateGetPacket(  type: type)
            case .v3:
                return ControlStateGetPacketV3(type: type, id: id)
            case .v5, .v5_2:
                return ControlStateGetPacketV5(type: type, id: id, persistence: persistenceMode)
        }
    }
    func getReturnPacket() -> ResultBasePacket {
        switch (connectionProtocolVersion) {
            case .unknown, .legacy, .v1, .v2:
                return ResultPacket()
            case .v3:
                return ResultPacketV3()
            case .v5, .v5_2:
                return ResultPacketV5()
        }
    }
    
    
}

public let StatePacketsGenerator = StatePacketsGeneratorClass()
