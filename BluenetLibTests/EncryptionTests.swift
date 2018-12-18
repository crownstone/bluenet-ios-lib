//
//  EncryptionTests.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 26/07/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import XCTest
import CryptoSwift
@testable import BluenetLib

class EncryptionTests: XCTestCase {
    var settings : BluenetSettings!
    
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        settings = BluenetSettings()
        //settings.loadKeys(encryptionEnabled: true, adminKey: "AdminKeyOf16Byte", memberKey: "MemberKeyOf16Byt", guestKey: "GuestKeyOf16Byte", referenceId: "test")
        
        BLUENET_ENCRYPTION_TESTING = true
        
    }
//    
//    override func tearDown() {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//        super.tearDown()
//    }
//    
//       
//    func testKeys() {
//        let adminKey   = try! EncryptionHandler._getKey(UserLevel.admin, settings)
//        let memberKey  = try! EncryptionHandler._getKey(UserLevel.member, settings)
//        let guestKey   = try! EncryptionHandler._getKey(UserLevel.guest, settings)
//
//        XCTAssertEqual(adminKey,  settings.adminKey!)
//        XCTAssertEqual(memberKey, settings.memberKey!)
//        XCTAssertEqual(guestKey,  settings.guestKey!)
//
//    }
//    
//    func testSwitchPacketEncryption() {
//        settings.setSessionNonce([49,50,51,52,53])
//        let payload : [UInt8] = [0,0,1,0,100]
//        let payloadData = Data(payload)
//        let data = try! EncryptionHandler.encrypt(payloadData, settings: settings)
//        
//        print("ENC DATA \(data.bytes)")
//    }
//
//    
//    func testNotificationPacketEncryption() {
//        settings.loadKeys(encryptionEnabled: true, adminKey: "f40a7ab9eb1c9909a35e4b5bb1c07bcd", memberKey: "dcad9f07f4a13339db066b4acf437646", guestKey: "9332b7abf19b86f548156d88c687def6", referenceId: "test")
//        settings.setSessionNonce([245, 128, 31, 110, 0])
//        let payload : [UInt8] =  [184, 200, 141, 1, 103, 184, 15, 98, 70, 17, 30, 224, 126, 226, 113, 105, 144, 144, 35, 180]
//        let payloadData = Data(payload)
//        let data = try? EncryptionHandler.decrypt(payloadData, settings: settings)
//        
//        print("dec data \(data)")
//    }
//    
//    func testEncryption() {
//        // we are going to try if the CTR method from Cryptswift is doing what we think its doing when adding the counter to the IV
//        settings.setSessionNonce([81,82,83,84,85])
//        let payload : [UInt8] = [1,2,3,4,5,6,7,8,9,10,11,12,13]
//        let payloadData = Data(payload)
//        let data = try! EncryptionHandler.encrypt(payloadData, settings: settings)
//        
//        print("ENC DATA \(data)")
//        // key we use above
//        let key = settings.adminKey
//        
//        // first part
//        var iv : [UInt8]             = [128, 128, 128, 81, 82, 83, 84, 85, 0, 0, 0, 0, 0, 0,  0,  0]
//        let validation : [UInt8]     = [81, 82, 83, 84]
//        let payloadPart1  : [UInt8]  = [1,  2,  3,  4, 5, 6, 7, 8, 9, 10, 11, 12]
//        let encryptionLoadPart1      = validation + payloadPart1
//        var encryptedDataPart1       = try! AES(key: key!, blockMode: CryptoSwift.BlockMode.ECB, padding: .noPadding).encrypt(iv)
//
//        for i in [Int](0...15) { encryptedDataPart1[i] ^= encryptionLoadPart1[i] } // perform XOR
//        
//        // second part
//        iv[iv.count-1] += 1
//        let payloadPart2  : [UInt8]  = [13,  0,   0,   0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0]
//        var encryptedDataPart2       = try! AES(key: key!, blockMode: CryptoSwift.BlockMode.ECB, padding: .noPadding).encrypt(iv)
//
//        for i in [Int](0...15) { encryptedDataPart2[i] ^= payloadPart2[i] } // perform XOR
//        
//        // this prefix contains the "random" numbers and the user level access.
//        let prefix : [UInt8] = [128, 128, 128, 0]
//        let emulatedCTRResult = prefix + encryptedDataPart1 + encryptedDataPart2
//    
//        
//        let uint8Arr = data.bytes
//        XCTAssertEqual(uint8Arr, emulatedCTRResult, "ctr mode not the same as expected ecb emulation")
//        
//        let decryptedData = try! EncryptionHandler.decrypt(data, settings: settings)
//        let decryptedUint8Array = decryptedData.bytes
//        
//        XCTAssertEqual(decryptedUint8Array, payloadPart1+payloadPart2, "decryption failed")
//        // we slice both the decrypted data and the payload so both are of type ArraySlice in order to match the contents
//        XCTAssertEqual(decryptedUint8Array[0...12], payload[0...payload.count-1], "decryption failed")
//
//    }
//    
//    func testCTREncryptionOnChip() {
//        // we are going to try if the CTR method from Cryptswift is doing what we think its doing when adding the counter to the IV
//        let payload : [UInt8] = [2,2,2,2]
//        settings.setSessionNonce([64,64,64,64,64])
//        settings.adminKey = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
//        let payloadData = Data(payload)
//        _ = try! EncryptionHandler.encrypt(payloadData, settings: settings)
//        
//
//        print(Conversion.uint32_to_uint8_array(0xcafebabe))
//    }
//    
//    func testMultiblockCTREncryptionOnChip() {
//        // we are going to try if the CTR method from Cryptswift is doing what we think its doing when adding the counter to the IV
//        settings.setSessionNonce([64,64,64,64,64])
//        let payload : [UInt8] = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26]
//        settings.adminKey = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
//        let payloadData = Data(bytes: payload)
//        _ = try! EncryptionHandler.encrypt(payloadData, settings: settings)
//
//    }
//    
//    func testECBEncryptionOnChip() {
//        let payload  : [UInt8]  = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
//        let key : [UInt8] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
//        let encryptedData = try! AES(key: key, blockMode: CryptoSwift.BlockMode.ECB, padding: .noPadding).encrypt(payload)
//        print(encryptedData)
//    }
//    
//    func testECBEncryptionAndDecryption() {
//        let payload  : [UInt8]  = [0, 0, 100, 0, 25]
//        let paddedData = zeroPadding.add(to: payload, blockSize: 16)
//        print("paddedData \(paddedData)")
//
//        let key : [UInt8] = Conversion.ascii_or_hex_string_to_16_byte_array("9e34c5a7da5c2b8d36e9fc5cf7497a6b")
//        print(key)
//        let encryptedData = try! AES(key: key, blockMode: CryptoSwift.BlockMode.ECB, padding: .noPadding).encrypt(paddedData)
//        print("encryptedData \(encryptedData)")
//        let decryptedData = try! AES(key: key, blockMode: CryptoSwift.BlockMode.ECB, padding: .noPadding).decrypt(encryptedData)
//        print("decryptedData \(decryptedData)")
//        
//        XCTAssertEqual(decryptedData[0...decryptedData.count-1], paddedData[0...paddedData.count-1], "decryption failed")
//    }
//    
//    func testEncryptionWithoutKey() {
//        let payload  : [UInt8]  = [0, 0, 100, 0, 25]
//        let paddedData = zeroPadding.add(to: payload, blockSize: 16)
//        print("paddedData \(paddedData)")
//        
//        let key : [UInt8] = [0];
//        do {
//            guard key.count   == 16 else { throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY }
//            guard paddedData.count == 16 else { throw BluenetError.INVALID_PACKAGE_FOR_ENCRYPTION_TOO_SHORT }
//            let aes = try AES(key: key, blockMode: CryptoSwift.BlockMode.ECB, padding: .noPadding)
//            print("GOT THE AES", aes)
//            let data = try aes.decrypt(paddedData)
//            print("DONE", data)
//        }
//        catch {
//            print("Could not decrypt advertisement \(error)")
//        }
//        
//        
//    }
}
