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
    case Admin = 0
    case User = 1
    case Guest = 2
    case UNKNOWN = 255
}

/**
 * This method is used to encrypt data and wrap the envelope around it according to protocol V5
 */
func encrypt(payload: NSData, userLevel: UserLevel, sessionId: UInt32, settings: BluenetSettings) throws -> NSData {
    // get byte array from data
    let payloadArray = payload.arrayOfBytes()
   
    // create Nonce array
    var nonce = [UInt8](count: 8, repeatedValue: 0)
    
    // fill Nonce with random stuff
    for i in [Int](0...7) {
        nonce[i] = UInt8(arc4random_uniform(255) + 1)
    }
    
    // get key
    let key = try _getKey(userLevel, settings)
    
    // pad payload with sessionId
    var sessionIdArray = Conversion.uint32_to_uint8_array(sessionId)
    var paddedPayload = [UInt8](count: payloadArray.count + 4, repeatedValue: 0)
    for i in [Int](0...3) {
        paddedPayload[i] = sessionIdArray[i]
    }
    // put the input data in the padded payload
    for (index, element) in payloadArray.enumerate() {
        paddedPayload[index+4] = element
    }
    
    let encryptedPayload = try AES(key: key, iv: nonce, blockMode: CipherBlockMode.CTR, padding: PKCS7()).encrypt(payload.arrayOfBytes())
    
    var result = [UInt8](count: 9 + encryptedPayload.count, repeatedValue: 0)
    
    // copy nonce into result
    for i in [Int](0...7) {
        result[i] = nonce[i]
    }
    
    // put level into result
    result[8] = UInt8(userLevel.rawValue)
    
    // copy encrypted payload into the result
    for i in [Int](0...encryptedPayload.count) {
        result[i+9] = encryptedPayload[i]
    }
    
    return NSData(bytes:result)
}



func decrypt(input: NSData, settings: BluenetSettings) throws -> NSData {
    // decrypt data
    let decrypted = try _decrypt(input, settings)
    
    // verify decryption success and strip checksum
    let result = try _verifyDecryption(decrypted)
    
    return NSData(bytes: result)
}

func _verifyDecryption(decrypted: [UInt8]) throws -> [UInt8] {
    if (Conversion.uint8_array_to_uint32(decrypted) == 0xcafebabe) { // this only looks at the first 4 bytes
        // remove checksum from decyption and return payload
        var result = [UInt8](count:decrypted.count - 4, repeatedValue: 0)
        for i in [Int](4...decrypted.count) {
            result[i-4] = decrypted[i]
        }
        return result
    }
    else {
        throw BleError.COULD_NOT_DECRYPT
    }
}

func _decrypt(input: NSData, _ settings: BluenetSettings) throws -> [UInt8] {
    let package = try EncryptedPackage(data: input)
    
    let key = try _getKey(package.userLevel, settings)
    
    let decrypted = try AES(key: key, iv: package.nonce, blockMode: CipherBlockMode.CTR).decrypt(package.getPayload())
    
    return decrypted
}

func _getKey(userLevel: UserLevel, _ settings: BluenetSettings) throws -> [UInt8] {
    if (settings.initializedKeys == false) {
        throw BleError.COULD_NOT_ENCRYPT_KEYS_NOT_SET
    }
    
    var key : [UInt8]?
    switch (userLevel) {
    case .Admin:
        key = settings.adminKey
    case .User:
        key = settings.userKey
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