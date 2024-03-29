//
//  BroadcastBuffer.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 13/12/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth

public enum BroadcastType : UInt8 {
    case noOp               = 0
    case multiSwitch        = 1
    case timeData           = 2
    case behaviourSettings  = 3
    case updateTrackedDevice = 4
    
    case other = 255
}

let AVAILABLE_PAYLOAD_SIZE = 11

class BroadcastBuffer {
    var referenceId: String
    var type : BroadcastType
    var elements = [BroadcastElement]()
    
    var elementSize    = 0

    init(referenceId: String, type: BroadcastType) {
        self.referenceId = referenceId
        self.type = type
    }
    
    func accepts(_ element: BroadcastElement) -> Bool {
        return element.referenceId == self.referenceId && element.type == self.type
    }
    
    
    func blocksAreBroadcasting() {
        for element in self.elements {
            element.broadcastHasStarted()
        }
    }
    
    func loadElement(_ element: BroadcastElement) {
        self.elementSize = element.getSize()
        self.elements.append(element)
    }
    
    func isFull() -> Bool {
        if (self.elements.count == 1) {
            if (self.elements[0].singular == true) {
                return true
            }
        }
        
        if (elements.count + 1) * self.elementSize > AVAILABLE_PAYLOAD_SIZE {
            return true
        }
        return false
    }
    
    func countRequired() -> Bool {
        switch self.type {
            case .multiSwitch:
                return true
            default:
                return false
        }
    }
    
    func getPacket(devicePreferences : DevicePreferences) -> [UInt8] {
        var data = [UInt8]()
        
        var nonceToUse = NSNumber(value: getCurrentTimestampForCrownstone()).uint32Value
        var useCustomNonce = false
    
        if (self.elements.count == 1) {
            // since the nonce is based on time, we might need to overwrite this with a crownstone time instead of the current time (if stone has no time yet)
            if (self.elements[0].singular == true && self.elements[0].customValidationNonce != nil) {
                nonceToUse = self.elements[0].customValidationNonce!
                useCustomNonce = true
            }
        }
        
        if (devicePreferences.useTimeBasedNonce == false && useCustomNonce == false) {
            nonceToUse = 0xCAFEBABE
        }
        
//        print("Creating buffer packet")
//        print("time \(Conversion.uint32_to_uint8_array(nonceToUse))")
//        print("type \(self.type.rawValue)")
//        print("length \(NSNumber(value: self.elements.count).uint8Value)")
        
        data += Conversion.uint32_to_uint8_array(nonceToUse)
        data.append(self.type.rawValue)
        
        if (self.countRequired()) {
            data.append(NSNumber(value: self.elements.count).uint8Value)
        }
        for element in self.elements {
//            print("ElementPacket \(element.getPacket())")
            data += element.getPacket()
        }
        
        return data
    }
    
    
}
