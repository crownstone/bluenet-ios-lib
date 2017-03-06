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
        settings.adminKey = Conversion.string_to_uint8_array(  "AdminKeyOf16Byte")
        settings.memberKey  = Conversion.string_to_uint8_array("MemberKeyOf16Byt")
        settings.guestKey = Conversion.string_to_uint8_array(  "GuestKeyOf16Byte")
        settings.initializedKeys = true
        
        BLUENET_ENCRYPTION_TESTING = true
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
       
    func testKeys() {
        let adminKey   = try! EncryptionHandler._getKey(UserLevel.admin, settings)
        let memberKey  = try! EncryptionHandler._getKey(UserLevel.member, settings)
        let guestKey   = try! EncryptionHandler._getKey(UserLevel.guest, settings)

        XCTAssertEqual(adminKey,  settings.adminKey!)
        XCTAssertEqual(memberKey, settings.memberKey!)
        XCTAssertEqual(guestKey,  settings.guestKey!)

    }

    
    func testEncryption() {
        // we are going to try if the CTR method from Cryptswift is doing what we think its doing when adding the counter to the IV
        let sessionData = try! SessionData([81,82,83,84,85])
        let payload : [UInt8] = [1,2,3,4,5,6,7,8,9,10,11,12,13]
        let payloadData = Data(payload)
        let data = try! EncryptionHandler.encrypt(payloadData, settings: settings)
        
        // key we use above
        let key = settings.adminKey
        
        // first part
        var iv : [UInt8]             = [128, 128, 128, 81, 82, 83, 84, 85, 0, 0, 0, 0, 0, 0,  0,  0]
        let validation : [UInt8]     = [81,  82,  83,  84]
        let payloadPart1  : [UInt8]  = [1,  2,  3,  4, 5, 6, 7, 8, 9, 10, 11, 12]
        let encryptionLoadPart1      = validation + payloadPart1
        var encryptedDataPart1       = try! AES(key: key!, blockMode: CryptoSwift.BlockMode.ECB, padding: zeroPadding()).encrypt(iv)
        for i in [Int](0...15) { encryptedDataPart1[i] ^= encryptionLoadPart1[i] } // perform XOR
        
        // second part
        iv[iv.count-1] += 1
        let payloadPart2  : [UInt8]  = [13,  0,   0,   0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0]
        var encryptedDataPart2       = try! AES(key: key!, blockMode: CryptoSwift.BlockMode.ECB, padding: zeroPadding()).encrypt(iv)
        for i in [Int](0...15) { encryptedDataPart2[i] ^= payloadPart2[i] } // perform XOR
        
        // this prefix contains the "random" numbers and the user level access.
        let prefix : [UInt8] = [128, 128, 128, 0]
        let emulatedCTRResult = prefix + encryptedDataPart1 + encryptedDataPart2
        
        
        let uint8Arr = Array(UnsafeBufferPointer(start: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), count: data.count))
        XCTAssertEqual(uint8Arr, emulatedCTRResult, "ctr mode not the same as expected ecb emulation")
        
        let decryptedData = try! EncryptionHandler.decrypt(data, settings: settings)
        
        let decryptedUint8Array = Array(UnsafeBufferPointer(start: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), count: data.count))
        XCTAssertEqual(decryptedUint8Array, payloadPart1+payloadPart2, "decryption failed")
        // we slice both the decrypted data and the payload so both are of type ArraySlice in order to match the contents
        XCTAssertEqual(decryptedUint8Array[0...12], payload[0...payload.count-1], "decryption failed")

    }
    
    func testCTREncryptionOnChip() {
        // we are going to try if the CTR method from Cryptswift is doing what we think its doing when adding the counter to the IV
        let sessionData = try! SessionData([64,64,64,64,64])
        let payload : [UInt8] = [2,2,2,2]
        settings.adminKey = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
        let payloadData = Data(payload)
        let data = try! EncryptionHandler.encrypt(payloadData, settings: settings)
        

        print(Conversion.uint32_to_uint8_array(0xcafebabe))
    }
    
    func testMultiblockCTREncryptionOnChip() {
        // we are going to try if the CTR method from Cryptswift is doing what we think its doing when adding the counter to the IV
        let sessionData = try! SessionData([64,64,64,64,64])
        let payload : [UInt8] = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26]
        settings.adminKey = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
        let payloadData = Data(bytes: payload)
        let data = try! EncryptionHandler.encrypt(payloadData, settings: settings)

    }
    
    func testECBEncryptionOnChip() {
        let payload  : [UInt8]  = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
        let key : [UInt8] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
        let encryptedData = try! AES(key: key, blockMode: CryptoSwift.BlockMode.ECB, padding: zeroPadding()).encrypt(payload)
        print(encryptedData)
    }
    
    func testECBEncryptionAndDecryption() {
        let payload  : [UInt8]  = [0, 0, 100, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let key : [UInt8] = [103, 117, 101, 115, 116, 75, 101, 121, 70, 111, 114, 71, 105, 114, 108, 115];
        let encryptedData = try! AES(key: key, blockMode: CryptoSwift.BlockMode.ECB, padding: zeroPadding()).encrypt(payload)
        print(encryptedData)
        let decryptedData = try! AES(key: key, blockMode: CryptoSwift.BlockMode.ECB, padding: zeroPadding()).decrypt(payload)
        print(decryptedData)
    }
}
