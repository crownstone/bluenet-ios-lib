//
//  BroadcastProtocol.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 04/12/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth
import UIKit

struct s128Bits {
    var a: UInt64 = 0
    var b: UInt64 = 0
}

public class BroadcastProtocol {
    
    
    /**
     This functionality will be disabled since it is not tested anymore.
     */
    public static func useDynamicBackground() -> Bool {
//        #if os(iOS)
//
//            let systemVersion = UIDevice.current.systemVersion
//            let versions = systemVersion.components(separatedBy: ".")
//            var major : Int? = 0
//            var minor : Int? = 0
//            var micro : Int? = 0
//
//            if versions.count > 2 {
//                major = Int(versions[0])
//                minor = Int(versions[1])
//                micro = Int(versions[2])
//            }
//            else if versions.count == 2 {
//                major = Int(versions[0])
//                minor = Int(versions[1])
//            }
//            else if versions.count == 1 {
//                major = Int(versions[0])
//            }
//
//            if let majorValue = major {
//                if majorValue < 13 {
//                    return true
//                }
//            }
//
//        #endif

        return false
    }
    
    
    /**
     * Payload is 12 bytes, this method will add the validation and encrypt the thing
     **/
    static func getEncryptedServiceUUID(referenceId: String, settings: BluenetSettings, data: [UInt8], nonce: [UInt8]) throws -> CBUUID {
        if settings.keysAvailable(referenceId: referenceId) {
            do {                
                
                let userLevel = settings.getUserLevel(referenceId: referenceId)
                if (userLevel == .unknown) {
                    throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY
                }
                
                let key = try settings.getKey(referenceId: referenceId, userLevel: userLevel)
                
                // HACK TO HAVE A STATIC NONCE
                let encryptedData = try EncryptionHandler.encryptBroadcast(Data(bytes:data), key: key, nonce: nonce)

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
    
    
    static func getUInt16ServiceNumbers(
        broadcastCounter: UInt8,
        locationState: LocationState,
        devicePreferences: DevicePreferences,
        protocolVersion: NSNumber,
        accessLevel: UserLevel,
        key : [UInt8]
    ) throws -> [UInt16]  {
        guard (locationState.locationId < 64) else {
            throw BluenetError.INVALID_BROADCAST_LOCATION_ID
        }
        guard (locationState.profileIndex < 8) else {
            throw BluenetError.INVALID_BROADCAST_PROFILE_INDEX
        }
        
        var result = [UInt16]()
        
        let firstPart = NSNumber(value: broadcastCounter).uint16Value << 8
        
        let RC5Component = BroadcastProtocol.getRC5Payload(firstPart: firstPart, locationState: locationState, devicePreferences: devicePreferences, key: key)
        result.append(BroadcastProtocol._constructProtocolBlock(protocolVersion, locationState.sphereUID, accessLevel))
        result.append(BroadcastProtocol._getFirstRC5Block(deviceToken: locationState.deviceToken, RC5: RC5Component))
        result.append(BroadcastProtocol._getSecondRC5Block(RC5Component))
        result.append(BroadcastProtocol._getThirdRC5Block(RC5Component))
        
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
     * This is an UInt32 which will be encrypted
     * | ----------- First Part ---------- |
     * | Counter         | Reserved        | LocationId  | Profile Index | RSSI Calibration | Flag: t2t enabled | Flag: ignore for behaviour | Flag: reserved |
     * | 0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 | 0 0 0         | 0 0 0 0          | 0                 | 0                          | 0              |
     * | 8b              | 8b              | 6b          | 3b            | 4b               | 1b                | 1b                         | 1b             |
     *
     * The first part will be a validation nonce in the background.
     *
     **/
    static func getRC5Payload(firstPart: UInt16, locationState: LocationState, devicePreferences: DevicePreferences, key: [UInt8]) -> UInt32 {
        var rc5Payload : UInt32 = 0
        
        rc5Payload += UInt32(firstPart) << 16
        
        rc5Payload += (NSNumber(value: locationState.locationId).uint32Value & 0x0000003F) << 10
        
        rc5Payload += (NSNumber(value: locationState.profileIndex).uint32Value & 0x00000007) << 7
        
        rc5Payload += (NSNumber(value: (devicePreferences.rssiOffset / 2) + 8).uint32Value & 0x0000000F) << 3
        
        if (devicePreferences.tapToToggle) {
            rc5Payload += UInt32(1) << 2
        }
        
        if (devicePreferences.ignoreForBehaviour) {
            rc5Payload += UInt32(1) << 1
        }
        
        return RC5Encrypt(input: rc5Payload, key: key)
    }
    
 
    
    
    /**
    * This is an UInt16 is constructed from an index flag, then a protocol,  the Sphere passkey and the access level
    *
    * | Index |  Protocol version |  Sphere UID      |  Access Level |
    * | 0 0   |  0 0 0            |  0 0 0 0 0 0 0 0 |  0 0 0        |
    * | 2b    |  3b               |  8b              |  3b           |
    *
    **/
    static func _constructProtocolBlock(_ protocolVersion: NSNumber, _ spherePasskey: UInt8?, _  accessLevel: UserLevel) -> UInt16 {
        var block : UInt16 = 0;
        
        block += (protocolVersion.uint16Value & 0x0007) << 11
        if (spherePasskey != nil) {
            block += (UInt16(spherePasskey!) & 0x00FF) << 3
        }
        block += NSNumber(value: accessLevel.rawValue).uint16Value & 0x0007
        
        return block
    }
    
    
    
    /**
     * TThe first chunk of RC5 data and reserved chunk of public bits
     *
     * | Index |  Reserved  |  Device Token     |  First chunk of RC5Data  |
     * | 0 1   |  0 0       |  0 0 0 0 0 0 0 0  |  0 0 0 0   |
     * | 2b    |  2b        |  8b                     |  4b          |
     *
     **/
    static func _getFirstRC5Block(deviceToken: UInt8, RC5: UInt32) -> UInt16 {
        var block : UInt16 = 0;
        
        block += 1 << 14 // place index
        
        // place device token
        block += NSNumber(value: deviceToken).uint16Value << 4
        
        block += NSNumber(value: (RC5 & 0xF0000000) >> 28).uint16Value
        
        return block
    }
    
    /**
     *
     * | Index |  RC chunk 2                       |
     * | 1 0   |  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0  |
     * | 2b    |  14b                              |
     *
     **/
    static func _getSecondRC5Block(_ RC5: UInt32) -> UInt16 {
        var block : UInt16 = 0;
        
        block += 1 << 15 // place index
        
        block += NSNumber(value: (RC5 & 0x0FFFC000) >> 14).uint16Value
        return block
    }
    
    /**
     *
     * | Index |  RC chunk 3                       |
     * | 1 1   |  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0  |
     * | 2b    |  14b                              |
     *
     **/
    static func _getThirdRC5Block(_ RC5: UInt32) -> UInt16 {
        var block : UInt16 = 0;
        
        block += 3 << 14 // place index
        block += NSNumber(value: RC5 & 0x00003FFF).uint16Value
        return block
    }
    
    
    
    public static func getServicesForBackgroundBroadcast(locationState: LocationState, devicePreferences: DevicePreferences, key: [UInt8]) -> [CBUUID] {
        let block = _constructBackgroundBlock(locationState: locationState, devicePreferences: devicePreferences, protocolVersion: 0, key: key)

        return getServicesFromBlock(block: block)
    }
    
    
    /**
    *
    * | Protocol |  Device Token                                                   |  Zeros
    * | 1 1         |  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0  |  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0  |
    * | 2b          |  24b                                                                   | 38b
    *
    * Validation is the time we would send to the crownstone T >> 7 & 0x0000FFFF
    *
    * Will return 64 bits, zero padded at the back
     **/
    public static func getServicesForStaticBackgroundBroadcast(devicePreferences: DevicePreferences) -> [CBUUID] {
        var block : UInt64 = 0
        // add the protocol
        block += NSNumber(value: 1).uint64Value << 62
        
        // inverse the endian-ness of the tracking number
        let trackingNumberBytes = Conversion.uint32_to_uint8_array(devicePreferences.trackingNumber)
        var trackingNumberUint64 : UInt64 = 0
        
        trackingNumberUint64 += NSNumber(value: trackingNumberBytes[2]).uint64Value
        trackingNumberUint64 += NSNumber(value: trackingNumberBytes[1]).uint64Value << 8
        trackingNumberUint64 += NSNumber(value: trackingNumberBytes[0]).uint64Value << 16
        
        block += trackingNumberUint64 << 38
        
        return getServicesFromBlock(block: block)
    }
    
    
    public static func getServicesFromBlock(block: UInt64) -> [CBUUID] {
        var payload = s128Bits()
        payload.a = block
        payload.a += block >> 42
        payload.b += block << 22
        payload.b += block >> 20

        // print the entire sequence as bits
//        var str = ""
//        for i in (0..<64).reversed() {
//            str += String(block >> i & 0x01)
//            if (i == 22) {
//                str += " "
//            }
//        }
//        print("part1", str)
//
//
//        str = ""
//        for i in (0..<64).reversed() {
//            str += String(payload.a >> i & 0x01)
//            if (i == 22) {
//                str += " "
//            }
//        }
//
//        print("part2", str)
//
//        str = ""
//        for i in (0..<64).reversed() {
//             str += String(payload.b >> i & 0x01)
//            if (i == 64-20) {
//                str += " "
//            }
//        }
//
//        print("part3", str)
//



        // printing the entire payload as a hex string
//        var uint8Buf = [Bool]()
//        str = "0x01"
//        for i in (0..<64).reversed() {
//            uint8Buf.append(payload.a >> i & 0x01 == 1)
//            if (uint8Buf.count == 8) {
//                str += Conversion.uint8_to_hex_string(Conversion.bit_array_to_uint8(uint8Buf.reversed()))
//                uint8Buf.removeAll()
//            }
//        }
//
//
//        for i in (0..<64).reversed() {
//            uint8Buf.append(payload.b >> i & 0x01 == 1)
//            if (uint8Buf.count == 8) {
//                str += Conversion.uint8_to_hex_string(Conversion.bit_array_to_uint8(uint8Buf.reversed()))
//                uint8Buf.removeAll()
//            }
//        }
//        print("Payload as HEX string", str)
//
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

                if (idx == 69) { continue } // this is the service hash of a new apple watch, triggering a popup on ios phones. We ignore it.

                services.append(CBUUID(string: serviceMap[idx]))
            }
        }
        
        return services
    }

    
    /**
     *
     * | Protocol |  Sphere UID       |  RC5 encrypted with basic key      32b                            | padding 0 times 22
     * | 1 1      |  0 0 0 0 0 0 0 0  |  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0  |
     * | 2b       |  8b               | | validation 16b                | payload 16b                   | |
     *
     * Validation is the time we would send to the crownstone T >> 7 & 0x0000FFFF
     *
     * Will return 64 bits, zero padded at the back
     **/
    static func _constructBackgroundBlock(locationState: LocationState, devicePreferences: DevicePreferences, protocolVersion: NSNumber, key: [UInt8]) -> UInt64 {
        let time = NSNumber(value: getCurrentTimestampForCrownstone()).uint32Value
        var validationTime = NSNumber(value: (time >> 7 & 0x0000FFFF)).uint16Value
        
        if (devicePreferences.useTimeBasedNonce == false) {
            validationTime = 0xCAFE
        }
        
        let encryptedBlock = BroadcastProtocol.getRC5Payload(firstPart: validationTime, locationState: locationState, devicePreferences: devicePreferences, key: key)
        
        var data : UInt64 = 0
        
        data += protocolVersion.uint64Value << 62

        data += UInt64(locationState.sphereUID) << 54
        
        data += UInt64(encryptedBlock) << 22
//        print("Background Block Encrypted \(data)")
        
        
        return data
    }
    
}

