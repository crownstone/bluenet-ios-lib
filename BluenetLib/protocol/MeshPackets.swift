//
//  MeshPackets.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 03/02/2017.
//  Copyright © 2017 Alex de Mulder. All rights reserved.
//

import Foundation

class MeshCommandPacket {
    var type          : UInt8 = 0
    var idCounter     : UInt8 = 0
    var crownstoneIds : [UInt8]!
    var payload       : [UInt8]!
    
    init(type: MeshCommandType, crownstoneIds: [UInt8], payload: [UInt8]) {
        self.type = type.rawValue
        self.crownstoneIds = crownstoneIds
        self.payload = payload
        self.idCounter = NSNumber(value: crownstoneIds.count).uint8Value
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(0) // reserved
        arr.append(self.idCounter)
        arr += (self.crownstoneIds)
        arr += self.payload
        
        return arr
    }
}


class MeshCommandPacketV5 {
    var type          : UInt8 = 0
    var idCounter     : UInt8 = 0
    var crownstoneIds : [UInt8]!
    var payload       : [UInt8]!
    var optionFlag    : UInt8 = 0
    var transmissions : UInt8 = 0
    
    
    init(type: MeshCommandType, crownstoneIds: [UInt8], payload: [UInt8], broadcast: Bool = false, ackAllIds : Bool = true, useKnownIds : Bool = false, transmissions: UInt8 = 0) {
        self.type          = type.rawValue
        self.crownstoneIds = crownstoneIds
        self.payload       = payload
        self.idCounter     = NSNumber(value: crownstoneIds.count).uint8Value
        
        var optionFlag : UInt8 = 0
        if broadcast   { optionFlag += 1 << 0; }
        if ackAllIds   { optionFlag += 1 << 1; }
        if useKnownIds { optionFlag += 1 << 2; }
        
        self.optionFlag    = optionFlag
        self.transmissions = transmissions
    }
    
    convenience init(type: MeshCommandType, payload: [UInt8], transmissions: UInt8 = 0) {
        self.init(type: type, crownstoneIds: [], payload: payload, broadcast: true, ackAllIds: false, useKnownIds: false, transmissions: transmissions)
    }
    
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(self.optionFlag)
        arr.append(self.transmissions)
        arr.append(self.idCounter)
        arr += (self.crownstoneIds)
        arr += self.payload
        
        return arr
    }
}

class StoneMultiSwitchPacket {
    var timeout : UInt16 = 0
    var crownstoneId : UInt8
    var state   : UInt8
    var intent  : UInt8
    
    convenience init(crownstoneId: UInt8, state: UInt8, intent: IntentType) {
        self.init(crownstoneId: crownstoneId, state: state, timeout:0, intent: intent.rawValue)
    }
    
    convenience init(crownstoneId: UInt8, state: Float, intent: IntentType) {
        self.init(crownstoneId: crownstoneId, state: state, timeout:0, intent: intent.rawValue)
    }
    
    convenience init(crownstoneId: UInt8, state: UInt8, timeout: UInt16, intent: IntentType) {
        let switchState = min(100, state)
        self.init(crownstoneId: crownstoneId, state: switchState, timeout: timeout, intent: intent.rawValue)
    }
    
    convenience init(crownstoneId: UInt8, state: Float, timeout: UInt16, intent: UInt8) {
        let switchState = min(100, state)
        self.init(crownstoneId: crownstoneId, state: switchState, timeout: timeout, intent: intent)
    }
    
    init(crownstoneId: UInt8, state: UInt8, timeout: UInt16, intent: UInt8) {
        self.timeout = timeout
        self.crownstoneId = crownstoneId
        self.state = state
        self.intent = intent
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.crownstoneId)
        arr.append(self.state)
        arr += Conversion.uint16_to_uint8_array(self.timeout)
        arr.append(self.intent)

        return arr
    }
}


class MeshMultiSwitchPacket {
    var type : UInt8
    var numberOfItems : UInt8
    var packets : [StoneMultiSwitchPacket]!
    
    init(type: MeshMultiSwitchType, packets: [StoneMultiSwitchPacket]) {
        self.type = type.rawValue
        self.numberOfItems = NSNumber(value: packets.count).uint8Value
        self.packets = packets
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.type)
        arr.append(self.numberOfItems)
        for packet in self.packets {
            arr += packet.getPacket()
        }
        return arr
    }
}



