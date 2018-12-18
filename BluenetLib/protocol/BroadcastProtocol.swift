//
//  BroadcastProtocol.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 04/12/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth

let BROADCAST_FILTER_TOKEN_STRING = Conversion.uint16_to_hex_string(0x33DC)

class BroadcastProtocol {
    
    /**
     * Payload is 12 bytes, this method will add the validation and encrypt the thing
     **/
    static func getEncryptedServiceUUID(referenceId: String, settings: BluenetSettings, data: [UInt8], nonce: [UInt8]) throws -> CBUUID {
        if (settings.setSessionId(referenceId: referenceId)) {
            do {
                // avoid encryption
//                var input = [UInt8]()
//                for byte in data {
//                    input.append(byte)
//                }
//                for _ in data.count..<16 {
//                    input.append(0)
//                }
//                return CBUUID(data: Data(bytes: input.reversed()))
                
                
                // we reverse the input here to save time on the Crownstones.
                let encryptedData = try EncryptionHandler.encryptBroadcast(Data(bytes:data.reversed()), settings: settings, nonce: nonce)
                return CBUUID(data: encryptedData)
            }
            catch let err {
                print("Could not encrypt", err)
                throw err
            }
        }
        else {
            print("ERROR: invalid referenceId")
            throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY
        }
    }
    
    
    static func getUInt16ServiceNumbers(locationState: LocationState, protocolVersion: NSNumber, accessLevel: UserLevel, time: Double) throws -> [UInt16]  {
        guard (locationState.locationId != nil   && locationState.locationId!  < 64 || locationState.locationId   == nil) else {
            throw BluenetError.INVALID_BROADCAST_ACCESS_LEVEL
        }
        guard (locationState.profileIndex != nil && locationState.profileIndex! < 4 || locationState.profileIndex == nil) else {
            throw BluenetError.INVALID_BROADCAST_PROFILE_INDEX
        }
        
        var result = [UInt16]()
        
        result.append(BroadcastProtocol._constructProtocolBlock(protocolVersion, accessLevel, locationState.profileIndex))
        result.append(BroadcastProtocol._constructPayloadBlock(0,0))
        result.append(BroadcastProtocol._constructLocationBlock(locationState.sphereUID, locationState.locationId))
        result.append(BroadcastProtocol._constructTimeBlock(time))
        
        return result
    }
    
    static func convertUInt16ListToUUID(_ uintList : [UInt16]) -> [CBUUID] {
        var result = [CBUUID]()
        
        for num in uintList {
            result.append(CBUUID(string: Conversion.uint16_to_hex_string(num)))
        }
        
        return result
    }
    
    
    /**
    * This is an UInt16 is constructed from an index flag, then a protocol, finally an access level and a profileIndex
    *
    * | Index |  Protocol version |  Access Level |  ProfileIndex |
    * | 0 0   |  0 0 0 0 0 0 0 0  |  0 0 0 0      |  0 0          |
    * | 2b    |  8b               |  4b           |  2b           |
    *
    **/
    static func _constructProtocolBlock(_ protocolVersion: NSNumber, _  accessLevel: UserLevel, _ profileIndex: UInt8?) -> UInt16 {
        var block : UInt16 = 0;
        
        block += protocolVersion.uint16Value << 6
        block += NSNumber(value: accessLevel.rawValue).uint16Value << 2
        if (profileIndex != nil) {
            block += UInt16(profileIndex!)
        }
        
        return block
    }
    
    /**
     * This is an UInt16 is constructed from an index flag, then a protocol, finally an access level and a profileIndex
     *
     * | Index |  Type |  Payload                  |
     * | 0 1   |  0 0  |  0 0 0 0 0 0 0 0 0 0 0 0  |
     * | 2b    |  2b   |  2b                       |
     *
     **/
    static func _constructPayloadBlock(_ type: NSNumber, _  payload: NSNumber) -> UInt16 {
        var block : UInt16 = 0;
        
        block += 1 << 14 // place index
        block += type.uint16Value << 12
        block += payload.uint16Value
        
        return block
    }
    
    /**
     * This is an UInt16 is constructed from an index flag, Sphere Passkey used to identify the sphere, and a locationId
     *
     * | Index |  SphereUID       |  Location Id  |
     * | 1 0   |  0 0 0 0 0 0 0 0 |  0 0 0 0 0 0  |
     * | 2b    |  8b              |  6b           |
     *
     **/
    static func _constructLocationBlock(_ spherePasskey: UInt8?, _ locationId: UInt8?) -> UInt16 {
        var block : UInt16 = 0;
        
        block += 1 << 15 // place index
        if (spherePasskey != nil) {
            block += UInt16(spherePasskey!) << 6
        }
        
        if (locationId != nil) {
            block += UInt16(locationId!)
        }
        
        return block
    }
    
    /**
     * This is an UInt16 is constructed from an index flag, Sphere Passkey used to identify the sphere, and a locationId
     *
     * | Index |  Time LSB                     |
     * | 1 0   |  0 0 0 0 0 0 0 0 0 0 0 0 0 0  |
     * | 2b    |  14b                          |
     *
     **/
    static func _constructTimeBlock(_ time: Double) -> UInt16 {
        var uint32Time = NSNumber(value: time).uint32Value
        uint32Time = uint32Time & 0x3FFF
        
        var block : UInt16 = 0;
        
        block += 3 << 14 // place index
        block += UInt16(uint32Time)
    
        return block
    }
    
}
