//
//  EncryptionHandler.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 21/07/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import CryptoSwift

public enum UserLevel: Int {
    case admin   = 0
    case member  = 1
    case guest   = 2
    case setup   = 100
    case unknown = 255
}

let NONCE_LENGTH            = 16
let SESSION_DATA_LENGTH     = 5
let SESSION_KEY_LENGTH      = 4
let PACKET_USERLEVEL_LENGTH = 1
let PACKET_NONCE_LENGTH     = 3
let CHECKSUM                : UInt32 = 0xcafebabe

var BLUENET_ENCRYPTION_TESTING = false

open class SessionData {
    var sessionNonce : [UInt8]!
    var validationKey : [UInt8]!
    
    init(_ sessionData: [UInt8]) throws {
        if (sessionData.count != SESSION_DATA_LENGTH) {
            throw BleError.INVALID_SESSION_DATA
        }
        
        sessionNonce = [UInt8](repeating: 0, count: SESSION_DATA_LENGTH)
        validationKey   = [UInt8](repeating: 0,  count: SESSION_KEY_LENGTH)

        for i in [Int](0...SESSION_KEY_LENGTH-1) {
            sessionNonce[i] = sessionData[i]
            validationKey[i] = sessionData[i]
        }
        sessionNonce[SESSION_DATA_LENGTH-1] = sessionData[SESSION_DATA_LENGTH-1]
    }
}

open class zeroPadding: Padding {
    open func add(to data: [UInt8], blockSize: Int) -> [UInt8] {
        if (data.count % blockSize != 0) {
            let offset = blockSize - (data.count % blockSize)
            let padding = [UInt8](repeating: 0, count: offset)
            let paddedData = data + padding

//            print ("final padded data: \(data.count) \(padding.count) \(padding) \(paddedData)")
            return paddedData
        }
        return data
    }
    
    open func remove(from data: [UInt8], blockSize: Int?) -> [UInt8] {
        return data
    }
}

class EncryptionHandler {
    init() {}
    
    
    static func getRandomNumbers() -> UInt8 {
        if (BLUENET_ENCRYPTION_TESTING) {
            return 128
        }
        return UInt8(arc4random_uniform(255) + 1)
    }
    
    /** 
     * This method is used to encrypt data and wrap the envelope around it according to protocol V5
     */
    static func encrypt(_ payload: Data, settings: BluenetSettings) throws -> Data {
        if (settings.sessionNonce == nil) {
            throw BleError.NO_SESSION_NONCE_SET
        }
        
        if (settings.userLevel == .unknown) {
            throw BleError.DO_NOT_HAVE_ENCRYPTION_KEY
        }
        
        // unpack the session data
        let sessionData = try SessionData(settings.sessionNonce!)
        
        // get byte array from data
        let payloadArray = payload.bytes
        
        // create Nonce array
        var nonce = [UInt8](repeating: 0, count: PACKET_NONCE_LENGTH)
        
        // fill Nonce with random stuff
        for i in [Int](0...PACKET_NONCE_LENGTH-1) {
            nonce[i] = getRandomNumbers()
        }
        
        let IV = try generateIV(nonce, sessionData: sessionData.sessionNonce)
        
        // get key
        let key = try _getKey(settings)
        
        // pad payload with sessionId
        var paddedPayload = [UInt8](repeating: 0, count: payloadArray.count + SESSION_KEY_LENGTH)
        for i in [Int](0...SESSION_KEY_LENGTH-1) {
            paddedPayload[i] = sessionData.validationKey[i]
        }
        
        // put the input data in the padded payload
        for (index, element) in payloadArray.enumerated() {
            paddedPayload[index+4] = element
        }
        
        // do the actual encryption
        let encryptedPayload = try AES(key: key, iv: IV, blockMode: CryptoSwift.BlockMode.CTR, padding: zeroPadding()).encrypt(paddedPayload)
        var result = [UInt8](repeating: 0, count: PACKET_NONCE_LENGTH+PACKET_USERLEVEL_LENGTH + encryptedPayload.count)
        
        // copy nonce into result
        for i in [Int](0...PACKET_NONCE_LENGTH-1) {
            result[i] = nonce[i]
        }
        
        // put level into result
        result[PACKET_NONCE_LENGTH] = UInt8(settings.userLevel.rawValue)
        
        // copy encrypted payload into the result
        for i in [Int](0...encryptedPayload.count-1) {
            let index = i + PACKET_NONCE_LENGTH + PACKET_USERLEVEL_LENGTH
            result[index] = encryptedPayload[i]
        }
        
        return Data(bytes:result)
    }
    
    static func decryptAdvertisement(_ input: [UInt8], key: [UInt8]) throws -> [UInt8] {
        return try AES(key: key, blockMode: CryptoSwift.BlockMode.ECB, padding: zeroPadding()).decrypt(input)
    }
    
    static func decryptSessionNonce(_ input: [UInt8], key: [UInt8]) throws -> [UInt8] {
        if (input.count == 16) {
            let result = try AES(key: key, blockMode: CryptoSwift.BlockMode.ECB, padding: zeroPadding()).decrypt(input)
            let checksum = Conversion.uint8_array_to_uint32(result)
            if (checksum == CHECKSUM) {
                return [result[4], result[5], result[6], result[7], result[8]]
            }
            else {
                throw BleError.COULD_NOT_VALIDATE_SESSION_NONCE
            }
        }
        else {
            throw BleError.READ_SESSION_NONCE_ZERO_MAYBE_ENCRYPTION_DISABLED
        }
    }
    
    static func decrypt(_ input: Data, settings: BluenetSettings) throws -> Data {
        if (settings.sessionNonce == nil) {
            throw BleError.NO_SESSION_NONCE_SET
        }
        
        // unpack the session data
        let sessionData = try SessionData(settings.sessionNonce!)

        // decrypt data
        let decrypted = try _decrypt(input, sessionData, settings)
        // verify decryption success and strip checksum
        let result = try _verifyDecryption(decrypted, sessionData)
        
        return Data(bytes: result)
    }
    
    static func _verifyDecryption(_ decrypted: [UInt8], _ sessionData: SessionData) throws -> [UInt8] {
        // the conversion to uint32 only takes the first 4 bytes
        if (Conversion.uint8_array_to_uint32(decrypted) == Conversion.uint8_array_to_uint32(sessionData.validationKey!)) {
            // remove checksum from decyption and return payload
            var result = [UInt8](repeating: 0, count: decrypted.count - SESSION_KEY_LENGTH)
            for i in [Int](SESSION_KEY_LENGTH...decrypted.count-1) {
                result[i-SESSION_KEY_LENGTH] = decrypted[i]
            }
            return result
        }
        else {
            throw BleError.COULD_NOT_DECRYPT
        }
    }
    
    static func _decrypt(_ input: Data, _ sessionData: SessionData, _ settings: BluenetSettings) throws -> [UInt8] {
        let package = try EncryptedPackage(data: input)
        let key = try _getKey(package.userLevel, settings)
        let IV = try generateIV(package.nonce, sessionData: sessionData.sessionNonce)
        
        let decrypted = try AES(key: key, iv: IV, blockMode: CryptoSwift.BlockMode.CTR).decrypt(package.getPayload())
        
        return decrypted
    }
    
    static func _getKey(_ settings: BluenetSettings) throws -> [UInt8] {
        return try _getKey(settings.userLevel, settings);
    }
    
    static func _getKey(_ userLevel: UserLevel, _ settings: BluenetSettings) throws -> [UInt8] {
        if (settings.initializedKeys == false && userLevel != .setup) {
            throw BleError.COULD_NOT_ENCRYPT_KEYS_NOT_SET
        }
        
        var key : [UInt8]?
        switch (userLevel) {
        case .admin:
            key = settings.adminKey
        case .member:
            key = settings.memberKey
        case .guest:
            key = settings.guestKey
        case .setup:
            key = settings.setupKey
        default:
            throw BleError.INVALID_KEY_FOR_ENCRYPTION
        }
        
        if (key == nil) {
            throw BleError.DO_NOT_HAVE_ENCRYPTION_KEY
        }
        
        return key!
    }
    
    static func generateIV(_ packetNonce: [UInt8], sessionData: [UInt8]) throws -> [UInt8] {
        if (packetNonce.count != PACKET_NONCE_LENGTH) {
            throw BleError.INVALID_SIZE_FOR_SESSION_NONCE_PACKET
        }
        var IV = [UInt8](repeating: 0, count: NONCE_LENGTH)
        // the IV used in the CTR mode is 8 bytes, the first 3 are random
        for i in [Int](0...PACKET_NONCE_LENGTH-1) {
            IV[i] = packetNonce[i]
        }
        
        // the IV used in the CTR mode is 8 bytes, the last 5 are from the session data
        for i in [Int](0...SESSION_DATA_LENGTH-1) {
            IV[i + PACKET_NONCE_LENGTH] = sessionData[i]
        }
        return IV
    }
}
