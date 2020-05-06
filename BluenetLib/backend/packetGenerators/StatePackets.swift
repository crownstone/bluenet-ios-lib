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
        if      self.connectionProtocolVersion == .v5 { return ControlStateSetPacketV5(type: StateTypeV3(rawValue: UInt16(type.rawValue))!) }
        else if self.connectionProtocolVersion == .v3 { return ControlStateSetPacket(  type: StateTypeV3(rawValue: UInt16(type.rawValue))!) }
        else                               { return WriteConfigPacket(type: type) }
    }
    func getWritePacket(type: StateType) -> BLEPacketBase {
        if      self.connectionProtocolVersion == .v5 { return ControlStateSetPacketV5(type: StateTypeV3(rawValue: UInt16(type.rawValue))!) }
        else if self.connectionProtocolVersion == .v3 { return ControlStateSetPacket(type: StateTypeV3(rawValue: UInt16(type.rawValue))!) }
        else                          { return WriteStatePacket(type: type) }
    }
    func getWritePacket(type: StateTypeV3, id: UInt16 = 0, persistenceMode: SetPersistenceMode = .STORED) -> BLEPacketBase {
        if self.connectionProtocolVersion == .v5 {
            return ControlStateSetPacketV5(type: type, id: id, persistence: persistenceMode)
        }
        else {
            return ControlStateSetPacket(type: type)
        }
    }
    
    func getReadPacket(type: ConfigurationType) -> BLEPacketBase {
        if      self.connectionProtocolVersion == .v5 { return ControlStateGetPacketV5(type: StateTypeV3(rawValue: UInt16(type.rawValue))!) }
        else if self.connectionProtocolVersion == .v3 { return ControlStateGetPacket(  type: StateTypeV3(rawValue: UInt16(type.rawValue))!) }
        else                          { return ReadConfigPacket(type: type) }
    }
    func getReadPacket(type: StateType) -> BLEPacketBase {
        if      self.connectionProtocolVersion == .v5 { return ControlStateGetPacketV5(type: StateTypeV3(rawValue: UInt16(type.rawValue))!) }
        else if self.connectionProtocolVersion == .v3 { return ControlStateGetPacket(  type: StateTypeV3(rawValue: UInt16(type.rawValue))!) }
        else                          { return ReadStatePacket(type: type) }
    }
    func getReadPacket(type: StateTypeV3, id: UInt16 = 0, persistenceMode: GetPersistenceMode = .CURRENT) -> BLEPacketBase {
        if      self.connectionProtocolVersion == .v5 { return ControlStateGetPacketV5(type: type, id: id, persistence: persistenceMode) }
        else if self.connectionProtocolVersion == .v3 { return ControlStateGetPacketV3(type: type, id: id) }
        else                               { return ControlStateGetPacket(  type: type) }
        
    }
    func getReturnPacket() -> ResultBasePacket {
        if self.connectionProtocolVersion == .v3 { return ResultPacketV3() }
        else                          { return ResultPacket() }
    }
    
    
}

public let StatePacketsGenerator = StatePacketsGeneratorClass()
