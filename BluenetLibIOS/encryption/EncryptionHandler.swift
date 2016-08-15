//
//  EncryptionHandler.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 21/07/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import CryptoSwift

enum UserLevel: Int {
    case Admin   = 0
    case Member  = 1
    case Guest   = 2
    case UNKNOWN = 255
}

let NONCE_LENGTH            = 16
let SESSION_DATA_LENGTH     = 5
let SESSION_KEY_LENGTH      = 4
let PACKET_USERLEVEL_LENGTH = 1
let PACKET_NONCE_LENGTH     = 3

var BLUENET_ENCRYPTION_TESTING = false

public class SessionData {
    var nonce : [UInt8]!
    var key   : [UInt8]!
    
    init(_ sessionData: [UInt8]) throws {
        if (sessionData.count != SESSION_DATA_LENGTH) {
            throw BleError.INVALID_SESSION_DATA
        }
        
        nonce = [UInt8](count: SESSION_DATA_LENGTH, repeatedValue: 0)
        key   = [UInt8](count: SESSION_KEY_LENGTH,  repeatedValue: 0)

        for i in [Int](0...SESSION_KEY_LENGTH-1) {
            nonce[i] = sessionData[i]
            key[i]   = sessionData[i]
        }
        nonce[SESSION_DATA_LENGTH-1] = sessionData[SESSION_DATA_LENGTH-1]
    }
}

public class zeroPadding: Padding {
    public func add(data: [UInt8], blockSize: Int) -> [UInt8] {
        if (data.count % blockSize != 0) {
            let offset = blockSize - (data.count % blockSize)
            let padding = [UInt8](count: offset, repeatedValue: 0)
            let paddedData = data + padding

//            print ("final padded data: \(data.count) \(padding.count) \(padding) \(paddedData)")
            return paddedData
        }
        return data
    }
    
    public func remove(data: [UInt8], blockSize: Int?) -> [UInt8] {
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
    static func encrypt(payload: NSData, userLevel: UserLevel, sessionData: SessionData, settings: BluenetSettings) throws -> NSData {
        // get byte array from data
        let payloadArray = payload.arrayOfBytes()
        
        // create Nonce array
        var nonce = [UInt8](count: PACKET_NONCE_LENGTH, repeatedValue: 0)
        
        // fill Nonce with random stuff
        for i in [Int](0...PACKET_NONCE_LENGTH-1) {
            nonce[i] = getRandomNumbers()
        }
        
        let IV = try generateIV(nonce, sessionData: sessionData.nonce)
        
        // get key
        let key = try _getKey(userLevel, settings)
        
        // pad payload with sessionId
        var paddedPayload = [UInt8](count: payloadArray.count + SESSION_KEY_LENGTH, repeatedValue: 0)
        for i in [Int](0...SESSION_KEY_LENGTH-1) {
            paddedPayload[i] = sessionData.key[i]
        }
        
        // put the input data in the padded payload
        for (index, element) in payloadArray.enumerate() {
            paddedPayload[index+4] = element
        }
        
        
        // do the actual encryption
        let encryptedPayload = try AES(key: key, iv: IV, blockMode: CipherBlockMode.CTR, padding: zeroPadding()).encrypt(paddedPayload)
        var result = [UInt8](count: PACKET_NONCE_LENGTH+PACKET_USERLEVEL_LENGTH + encryptedPayload.count, repeatedValue: 0)
        
        // copy nonce into result
        for i in [Int](0...PACKET_NONCE_LENGTH-1) {
            result[i] = nonce[i]
        }
        
        // put level into result
        result[PACKET_NONCE_LENGTH] = UInt8(userLevel.rawValue)
        
        // copy encrypted payload into the result
        for i in [Int](0...encryptedPayload.count-1) {
            let index = i + PACKET_NONCE_LENGTH + PACKET_USERLEVEL_LENGTH
            result[index] = encryptedPayload[i]
        }
        
        return NSData(bytes:result)
    }
    
    static func decryptAdvertisement(input: [UInt8], key: [UInt8]) -> [UInt8]? {
        print ("input count: \(input.count) \(input), key count: \(key) \(key.count)")
        do {
            let result = try! AES(key: key, blockMode: CipherBlockMode.ECB, padding: zeroPadding()).decrypt(input)
            return result
        }
        catch is ErrorType {
            print ("error")
            return nil
        }
    }
    
    static func decrypt(input: NSData, sessionData: SessionData, settings: BluenetSettings) throws -> NSData {
        // decrypt data
        let decrypted = try _decrypt(input, sessionData, settings)
        // verify decryption success and strip checksum
        let result = try _verifyDecryption(decrypted, sessionData)
        
        return NSData(bytes: result)
    }
    
    static func _verifyDecryption(decrypted: [UInt8], _ sessionData: SessionData) throws -> [UInt8] {
        // the conversion to uint32 only takes the first 4 bytes
        if (Conversion.uint8_array_to_uint32(decrypted) == Conversion.uint8_array_to_uint32(sessionData.key!)) {
            // remove checksum from decyption and return payload
            var result = [UInt8](count:decrypted.count - SESSION_KEY_LENGTH, repeatedValue: 0)
            for i in [Int](SESSION_KEY_LENGTH...decrypted.count-1) {
                result[i-SESSION_KEY_LENGTH] = decrypted[i]
            }
            return result
        }
        else {
            throw BleError.COULD_NOT_DECRYPT
        }
    }
    
    static func _decrypt(input: NSData, _ sessionData: SessionData, _ settings: BluenetSettings) throws -> [UInt8] {
        let package = try EncryptedPackage(data: input)
        
        let key = try _getKey(package.userLevel, settings)
        let IV = try generateIV(package.nonce, sessionData: sessionData.nonce)
        
        let decrypted = try AES(key: key, iv: IV, blockMode: CipherBlockMode.CTR).decrypt(package.getPayload())
        
        return decrypted
    }
    
    static func _getKey(userLevel: UserLevel, _ settings: BluenetSettings) throws -> [UInt8] {
        if (settings.initializedKeys == false) {
            throw BleError.COULD_NOT_ENCRYPT_KEYS_NOT_SET
        }
        
        var key : [UInt8]?
        switch (userLevel) {
        case .Admin:
            key = settings.adminKey
        case .Member:
            key = settings.memberKey
        case .Guest:
            key = settings.guestKey
        default:
            throw BleError.INVALID_KEY_FOR_ENCRYPTION
        }
        
        if (key == nil) {
            throw BleError.DO_NOT_HAVE_ENCRYPTION_KEY
        }
        
        return key!
    }
    
    static func generateIV(packetNonce: [UInt8], sessionData: [UInt8]) throws -> [UInt8] {
        if (packetNonce.count != PACKET_NONCE_LENGTH) {
            throw BleError.INVALID_SIZE_FOR_SESSION_NONCE_PACKET
        }
        var IV = [UInt8](count: NONCE_LENGTH, repeatedValue: 0)
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
