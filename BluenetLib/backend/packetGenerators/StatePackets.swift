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
    var controlVersion : ControlVersionType = .v1
    
    init() {}
    
  
    func getWritePacket(type: ConfigurationType) -> BLEPacketBase {
        if self.controlVersion == .v2 { return ControlStateSetPacket(type: StateTypeV2(rawValue: UInt16(type.rawValue))!) }
        else                          { return WriteConfigPacket(type: type) }
    }
    func getWritePacket(type: StateType) -> BLEPacketBase {
        if self.controlVersion == .v2 { return ControlStateSetPacket(type: StateTypeV2(rawValue: UInt16(type.rawValue))!) }
        else                          { return WriteStatePacket(type: type) }
    }
    func getWritePacket(type: StateTypeV2) -> BLEPacketBase {
        return ControlStateSetPacket(type: type)
    }
    
    func getReadPacket(type: ConfigurationType) -> BLEPacketBase {
        if self.controlVersion == .v2 { return ControlStateGetPacket(type: StateTypeV2(rawValue: UInt16(type.rawValue))!) }
        else                          { return ReadConfigPacket(type: type) }
    }
    func getReadPacket(type: StateType) -> BLEPacketBase {
        if self.controlVersion == .v2 { return ControlStateGetPacket(type: StateTypeV2(rawValue: UInt16(type.rawValue))!) }
        else                          { return ReadStatePacket(type: type) }
    }
    func getReadPacket(type: StateTypeV2) -> BLEPacketBase {
        return ControlStateGetPacket(type: type)
    }
    
    func getReturnPacket() -> ResultBasePacket {
        if self.controlVersion == .v2 { return ResultPacketV2() }
        else                          { return ResultPacket() }
    }
}

public let StatePacketsGenerator = StatePacketsGeneratorClass()
