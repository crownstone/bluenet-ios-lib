//
//  BroadcastProtocol.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 04/12/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth


struct s128Bits {
    var a: UInt64 = 0
    var b: UInt64 = 0
}

public class BroadcastProtocol {
    
    /**
     * Payload is 12 bytes, this method will add the validation and encrypt the thing
     **/
    static func getEncryptedServiceUUID(referenceId: String, settings: BluenetSettings, data: [UInt8], nonce: [UInt8]) throws -> CBUUID {
        if (settings.setSessionId(referenceId: referenceId)) {
            do {                
                // we reverse the input here to save time on the Crownstones.
                let encryptedData = try EncryptionHandler.encryptBroadcast(Data(bytes:data), settings: settings, nonce: nonce)
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
    
    
    static func getUInt16ServiceNumbers(locationState: LocationState, protocolVersion: NSNumber, accessLevel: UserLevel) throws -> [UInt16]  {
        guard (locationState.locationId != nil   && locationState.locationId!  < 64 || locationState.locationId   == nil) else {
            throw BluenetError.INVALID_BROADCAST_ACCESS_LEVEL
        }
        guard (locationState.profileIndex != nil && locationState.profileIndex! < 4 || locationState.profileIndex == nil) else {
            throw BluenetError.INVALID_BROADCAST_PROFILE_INDEX
        }
        
        var result = [UInt16]()
        
        result.append(BroadcastProtocol._constructProtocolBlock(protocolVersion, accessLevel, locationState.profileIndex))
        result.append(BroadcastProtocol._constructLocationBlock(locationState.sphereUID, locationState.locationId))
        result.append(BroadcastProtocol._constructPayloadBlock(0,0))
        result.append(BroadcastProtocol._constructPayloadExtBlock(0))
        
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
    * | 0 0   |  0 0 0 0 0 0 0 0  |  0 0 0        |  0 0 0        |
    * | 2b    |  8b               |  3b           |  3b           |
    *
    **/
    static func _constructProtocolBlock(_ protocolVersion: NSNumber, _  accessLevel: UserLevel, _ profileIndex: UInt8?) -> UInt16 {
        var block : UInt16 = 0;
        
        block += (protocolVersion.uint16Value << 6) & 0x3FFF
        block += NSNumber(value: accessLevel.rawValue).uint16Value & 0x0007 << 3
        if (profileIndex != nil) {
            block += UInt16(profileIndex!) & 0x0007
        }
        
        return block
    }
    
    
    
    /**
     * This is an UInt16 is constructed from an index flag, Sphere Passkey used to identify the sphere, and a locationId
     *
     * | Index |  SphereUID       |  Location Id  |
     * | 0 1   |  0 0 0 0 0 0 0 0 |  0 0 0 0 0 0  |
     * | 2b    |  8b              |  6b           |
     *
     **/
    static func _constructLocationBlock(_ spherePasskey: UInt8?, _ locationId: UInt8?) -> UInt16 {
        var block : UInt16 = 0;
        
        block += 1 << 14 // place index
        if (spherePasskey != nil) {
            block += UInt16(spherePasskey!) << 6 & 0x3FFF
        }
        
        if (locationId != nil) {
            block += UInt16(locationId!) & 0x003F
        }
        
        return block
    }
    
    /**
     *
     *
     * | Index |  Type    |  Payload                  |
     * | 1 0   |  0 0 0 0 |  0 0 0 0 0 0 0 0 0 0 0 0  |
     * | 2b    |  4b      |  12b                      |
     *
     **/
    static func _constructPayloadBlock(_ type: NSNumber, _  payload: NSNumber) -> UInt16 {
        var block : UInt16 = 0;
        
        block += 1 << 15 // place index
        block += type.uint16Value << 12 & 0x3FFF
        block += payload.uint16Value    & 0x3FFF
        
        return block
    }
    
    /**
     *
     * | Index |  Payload extended             |
     * | 1 1   |  0 0 0 0 0 0 0 0 0 0 0 0 0 0  |
     * | 2b    |  14b                          |
     *
     **/
    static func _constructPayloadExtBlock(_ payload: UInt16) -> UInt16 {
        var block : UInt16 = 0;
        
        block += 3 << 14 // place index
        block += payload & 0x3FFF
    
        return block
    }
    
    
    
    public static func getServicesForBackgroundBroadcast(locationState: LocationState, key: [UInt8]) -> [CBUUID] {
        var payload = s128Bits()
        
        let block = _constructBackgroundBlock(locationState: locationState, key: key)
        payload.a = block
        payload.a += block >> 42
        payload.b += block << 22
        payload.b += block >> 20
        
        var str = ""
        for i in (0..<64).reversed() {
            str += String(block >> i & 0x01)
            if (i == 22) {
                str += " "
            }
        }
        print("i", str)
        
        str = ""
        for i in (0..<64).reversed() {
            str += String(payload.a >> i & 0x01)
            if (i == 22) {
                str += " "
            }
        }
        print("a", str)
        
        str = ""
        for i in (0..<64).reversed() {
             str += String(payload.b >> i & 0x01)
            if (i == 40) {
                str += " "
            }
        }
        print("b", str)
        
    
        
        var uint8Buf = [Bool]()
        str = "0x01"
        for i in (0..<64).reversed() {
            uint8Buf.append(payload.a >> i & 0x01 == 1)
            if (uint8Buf.count == 8) {
                print("Casting \(uint8Buf) to \(Conversion.uint8_to_hex_string(Conversion.bit_array_to_uint8(uint8Buf.reversed())))")
                str += Conversion.uint8_to_hex_string(Conversion.bit_array_to_uint8(uint8Buf.reversed()))
                uint8Buf.removeAll()
            }
        }
        print("a hex", str)
        

        for i in (0..<64).reversed() {
            uint8Buf.append(payload.b >> i & 0x01 == 1)
            if (uint8Buf.count == 8) {
                str += Conversion.uint8_to_hex_string(Conversion.bit_array_to_uint8(uint8Buf.reversed()))
                uint8Buf.removeAll()
            }
        }
        print("b hex", str)

        
        var services = [CBUUID]()

        
        for i in (0..<64).reversed() {
            if ((payload.a >> i & 0x01) == 1) {
                let idx = 63-i
                services.append(CBUUID(string: serviceMap[idx]))
            }
        }
        
        for i in (0..<64).reversed() {
            if ((payload.b >> i & 0x01) == 1) {
                let idx = (63-i)+64
                services.append(CBUUID(string: serviceMap[idx]))
            }
        }

        
        return services
    }
    
    
    
    /**
     *
     * | Protocol |  Sphere UID       |  RC5 encrypted with guest key      32b                            | padding 0 times 22
     * | 1 1      |  0 0 0 0 0 0 0 0  |  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0  |
     * | 2b       |  8b               | | validation 16b                | payload 16b                   | |
     *
     * Validation is the time we would send to the crownstone T >> 7 & 0x0000FFFF
     *
     * Will return 64 bits, zero padded at the back
     **/
    static func _constructBackgroundBlock(locationState: LocationState, key: [UInt8]) -> UInt64 {
        var encryptingBlock : UInt32 = 0;
        let time = NSNumber(value: getCurrentTimestampForCrownstone()).uint32Value
        let validationTime = NSNumber(value: (time >> 7 & 0x0000FFFF)).uint16Value
        
        
        encryptingBlock += UInt32(validationTime) << 16
        if let locationId = locationState.locationId {
            encryptingBlock += UInt32(locationId)
        }
        
        let encryptedBlock = RC5Encrypt(input: encryptingBlock, key: key)
        
        var data : UInt64 = 0

        if let sphereUID = locationState.sphereUID {
            data += UInt64(sphereUID) << 54
        }
        
        data += UInt64(encryptedBlock) << 22
        
        return data
    }
    
}

