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
    case basic   = 2
    case setup   = 100
    case unknown = 255
}

let NONCE_LENGTH            = 16
let SESSION_DATA_LENGTH     = 5
let SESSION_KEY_LENGTH      = 4
let PACKET_USERLEVEL_LENGTH = 1
let PACKET_NONCE_LENGTH     = 3
let CHECKSUM      : UInt32 = 0xcafebabe

var BLUENET_ENCRYPTION_TESTING = false

public class SessionData {
    var sessionNonce  : [UInt8]!
    var validationKey : [UInt8]!
    
    init(_ connectionState: ConnectionState) throws {
        if (connectionState.sessionNonce != nil && connectionState.sessionNonce!.count != SESSION_DATA_LENGTH) {
            throw BluenetError.INVALID_SESSION_DATA
        }
        
        if (connectionState.validationKey != nil && connectionState.validationKey!.count != SESSION_KEY_LENGTH) {
            throw BluenetError.INVALID_SESSION_DATA
        }
        
        sessionNonce  = connectionState.sessionNonce!
        validationKey = connectionState.validationKey!
    }
}

public class zeroPadding {
    static public func add(to data: [UInt8], blockSize: Int) -> [UInt8] {
        if (data.count % blockSize != 0) {
            let offset = blockSize - (data.count % blockSize)
            let padding = [UInt8](repeating: 0, count: offset)
            let paddedData = data + padding
            return paddedData
        }
        
        return data
    }
    
     static public func remove(from data: [UInt8], blockSize: Int?) -> [UInt8] {
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
     * This method is used to encrypt data with the CTR method and wrap the envelope around it according to protocol V5
     */
    static func encrypt(_ payload: Data, connectionState: ConnectionState) throws -> Data {
        if connectionState.sessionNonce == nil {
            throw BluenetError.NO_SESSION_NONCE_SET
        }
        
        if connectionState.userLevel == .unknown {
            throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY
        }
        
        // unpack the session data
        let sessionData = try SessionData(connectionState)
        
        // get byte array from data
        let payloadArray = payload.bytes
        
        // create Nonce array
        var nonce = [UInt8](repeating: 0, count: PACKET_NONCE_LENGTH)
        
        // fill Nonce with random stuff
        for i in [Int](0..<PACKET_NONCE_LENGTH) {
            nonce[i] = getRandomNumbers()
        }
        
        let IV = try generateIV(nonce, sessionData: sessionData.sessionNonce)
        // get key
        let key = try _getKey(connectionState)
        
        // pad payload with sessionId
        var paddedPayload = [UInt8](repeating: 0, count: payloadArray.count + SESSION_KEY_LENGTH)
        for i in [Int](0..<SESSION_KEY_LENGTH) {
            paddedPayload[i] = sessionData.validationKey[i]
        }
        
        // put the input data in the padded payload
        for (index, element) in payloadArray.enumerated() {
            paddedPayload[index+SESSION_KEY_LENGTH] = element
        }
        
        // manually padd the payload since the CryptoSwift version is not working for CTR.
        let finalPayloadForEncryption = zeroPadding.add(to: paddedPayload, blockSize: 16);
        
        // do the actual encryption
        let encryptedPayload = try AES(key: key, blockMode: CryptoSwift.CTR(iv: IV), padding: .noPadding).encrypt(finalPayloadForEncryption)
        var result = [UInt8](repeating: 0, count: PACKET_NONCE_LENGTH+PACKET_USERLEVEL_LENGTH + encryptedPayload.count)
        
        // copy nonce into result
        for i in [Int](0..<PACKET_NONCE_LENGTH) {
            result[i] = nonce[i]
        }
        
        // put level into result
        result[PACKET_NONCE_LENGTH] = UInt8(connectionState.userLevel.rawValue)
        
        // copy encrypted payload into the result
        for i in [Int](0..<encryptedPayload.count) {
            let index = i + PACKET_NONCE_LENGTH + PACKET_USERLEVEL_LENGTH
            result[index] = encryptedPayload[i]
        }
        
        return Data(bytes:result)
    }
    
    
    /**
     * This method is used to encrypt data with the CTR method and wrap the envelope around it according to protocol V5
     */
    static func encryptBroadcast(_ payload: Data, key: [UInt8], nonce: [UInt8]) throws -> Data {        
        // get byte array from data
        let payloadArray = payload.bytes
        
        let IV = nonce + [UInt8](repeating: 0, count: NONCE_LENGTH - nonce.count)
        
        // manually padd the payload since the CryptoSwift version is not working for CTR.
        let finalPayloadForEncryption = zeroPadding.add(to: payloadArray, blockSize: 16);
        
        // do the actual encryption
        let encryptedPayload = try AES(key: key, blockMode: CryptoSwift.CTR(iv: IV), padding: .noPadding).encrypt(finalPayloadForEncryption)
        return Data(bytes:encryptedPayload.reversed())
    }
    
    
    
    
//    /**
//     * This method is used to encrypt data with the ECB method and wrap the envelope around it according to protocol V5
//     */
//    static func encryptECB(_ payload: [UInt8], key: [UInt8]) throws -> Data {
//        if (settings.userLevel == .unknown) {
//            throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY
//        }
//
//        // get key
//        let key = try _getKey(settings)
//
//        // manually padd the payload since the CryptoSwift version is not working for CTR.
//        let finalPayloadForEncryption = zeroPadding.add(to: payload, blockSize: 16);
//
//        // do the actual encryption
//        let encryptedPayload = try AES(key: key, blockMode: CryptoSwift.ECB(), padding: .noPadding).encrypt(finalPayloadForEncryption)
//
//        return Data(bytes:encryptedPayload)
//    }
    
    static func decryptAdvertisementSlice(_ input: ArraySlice<UInt8>, key: [UInt8]) throws -> [UInt8] {
        guard key.count   == 16 else { throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY }
        guard input.count == 16 else { throw BluenetError.INVALID_PACKAGE_FOR_ENCRYPTION_TOO_SHORT }
        return try AES(key: key, blockMode: CryptoSwift.ECB(), padding: .noPadding).decrypt(input)
    }
    
    static func decryptAdvertisement(_ input: [UInt8], key: [UInt8]) throws -> [UInt8] {
        guard key.count   == 16 else { throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY }
        guard input.count == 16 else { throw BluenetError.INVALID_PACKAGE_FOR_ENCRYPTION_TOO_SHORT }
        return try AES(key: key, blockMode: CryptoSwift.ECB(), padding: .noPadding).decrypt(input)
    }
    
    
    static func _decryptSessionData(_ input: [UInt8], key: [UInt8], connectionState: ConnectionState) throws -> DataStepper {
        var payload : DataStepper
        if (input.count == 16) {
            guard key.count == 16 else { throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY }
            let result = try AES(key: key, blockMode: CryptoSwift.ECB(), padding: .noPadding).decrypt(input)
            payload = DataStepper(result)
            
            let checksum = try payload.getUInt32();
            if (checksum != CHECKSUM) {
                throw BluenetError.COULD_NOT_VALIDATE_SESSION_NONCE
            }
        }
        else {
            throw BluenetError.READ_SESSION_NONCE_ZERO_MAYBE_ENCRYPTION_DISABLED
        }
        
        return payload
    }
    
    static func processSessionData(_ input: [UInt8], key: [UInt8], connectionState: ConnectionState) throws {
        var payload : DataStepper
        
        // we first check which mode we're in since older firmwares didnt encrypt the session data in setup mode.
        if (connectionState.operationMode == .setup) {
            switch (connectionState.connectionProtocolVersion) {
            case  .unknown, .legacy, .v1, .v2, .v3:
               if (input.count == 5) {
                    payload = DataStepper(input)
               }
               else {
                   throw BluenetError.READ_SESSION_NONCE_ZERO_MAYBE_ENCRYPTION_DISABLED
               }
            case .v5, .v5_2:
                payload = try EncryptionHandler._decryptSessionData(input, key: key, connectionState: connectionState)
            }
        }
        else if (connectionState.operationMode == .operation) {
            payload = try EncryptionHandler._decryptSessionData(input, key: key, connectionState: connectionState)
        }
        else {
            throw BluenetError.CANNOT_DO_THIS_IN_DFU_MODE
        }
        
        var protocolVersion : UInt8 = 0
        var sessionNonce : [UInt8]
        var validationKey: [UInt8]
        if (connectionState.connectionProtocolVersion == .v5) {
            protocolVersion = try payload.getUInt8()
            sessionNonce    = try payload.getBytes(5)
            validationKey   = try payload.getBytes(4)
            
            let protocolEnum = ConnectionProtocolVersion.init(rawValue: protocolVersion)
            
            if protocolVersion != 5 && protocolEnum != nil {
                connectionState.setConnectionProtocolVersion(protocolEnum!)
            }
        }
        else {
            payload.mark()
            sessionNonce = try payload.getBytes(5)
            payload.reset()
            validationKey = try payload.getBytes(4)
        }
        LOG.info("BLUENET_LIB: SetSessionNonce Nonce:\(sessionNonce) validationKey:\(validationKey) protocolVersion:\(protocolVersion)");
        connectionState.setSessionNonce(sessionNonce)
        connectionState.setProtocolVersion(protocolVersion)
        connectionState.validationKey(validationKey)
    }
    
    static func decrypt(_ input: Data, connectionState: ConnectionState) throws -> Data {
        if connectionState.sessionNonce == nil {
            throw BluenetError.NO_SESSION_NONCE_SET
        }
        
        // unpack the session data
        let sessionData = try SessionData(connectionState)

        // decrypt data
        let package = try EncryptedPackage(data: input)
        let key     = try _getKey(package.userLevel, connectionState)
        let IV      = try generateIV(package.nonce, sessionData: sessionData.sessionNonce)

        let decrypted = try AES(key: key, blockMode: CryptoSwift.CTR(iv: IV), padding: .noPadding).decrypt(package.getPayload())
        
        // verify decryption success and strip checksum
        let result = try _verifyDecryption(decrypted, sessionData)
        
        return Data(bytes: result)
    }
    
    static func _verifyDecryption(_ decrypted: [UInt8], _ sessionData: SessionData) throws -> [UInt8] {
        // the conversion to uint32 only takes the first 4 bytes
        if (Conversion.uint8_array_to_uint32(decrypted) == Conversion.uint8_array_to_uint32(sessionData.validationKey!)) {
            // remove checksum from decyption and return payload
            var result = [UInt8](repeating: 0, count: decrypted.count - SESSION_KEY_LENGTH)
            for i in [Int](SESSION_KEY_LENGTH..<decrypted.count) {
                result[i-SESSION_KEY_LENGTH] = decrypted[i]
            }
            return result
        }
        else {
            throw BluenetError.COULD_NOT_DECRYPT
        }
    }

    
    static func _getKey(_ connectionState: ConnectionState) throws -> [UInt8] {
        return try _getKey(connectionState.userLevel, connectionState);
    }
    
    
    
    static func _getKey(_ userLevel: UserLevel, _ connectionState: ConnectionState ) throws -> [UInt8] {
        if userLevel == .unknown || userLevel != .setup && connectionState.keySet == nil {
            throw BluenetError.COULD_NOT_ENCRYPT_KEYS_NOT_SET
        }
        
        var key : [UInt8]?
        switch (userLevel) {
        case .admin:
            key = connectionState.keySet!.adminKey
        case .member:
            key = connectionState.keySet!.memberKey
        case .basic:
            key = connectionState.keySet!.basicKey
        case .setup:
            key = connectionState.setupKey
        default:
            throw BluenetError.INVALID_KEY_FOR_ENCRYPTION
        }
        
        if (key == nil) {
            throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY
        }
        
        if (key!.count != 16) {
            throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY
        }
        
        return key!
    }
    
    static func generateIV(_ packetNonce: [UInt8], sessionData: [UInt8]) throws -> [UInt8] {
        if (packetNonce.count != PACKET_NONCE_LENGTH) {
            throw BluenetError.INVALID_SIZE_FOR_SESSION_NONCE_PACKET
        }
        var IV = [UInt8](repeating: 0, count: NONCE_LENGTH)
        // the IV used in the CTR mode is 8 bytes, the first 3 are random
        for i in [Int](0..<PACKET_NONCE_LENGTH) {
            IV[i] = packetNonce[i]
        }
        
        // the IV used in the CTR mode is 8 bytes, the last 5 are from the session data
        for i in [Int](0..<SESSION_DATA_LENGTH) {
            IV[i + PACKET_NONCE_LENGTH] = sessionData[i]
        }
        return IV
    }
}
