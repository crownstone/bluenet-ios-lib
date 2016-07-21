//
//  EncryptedPackage.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 21/07/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

/**
 *
 *
 */
class EncryptedPackage {
    var nonce : [UInt8]!
    var userLevel : UserLevel
    var payload : [UInt8]?
    
    init(data: NSData) throws {
        nonce = [UInt8](count: 8, repeatedValue: 0);
        var dataArray = data.arrayOfBytes();
        var payloadData = [UInt8](count: dataArray.count - 9, repeatedValue:0)
        
        // 25 is the minimal size of a packet (8+1+16)
        if (dataArray.count >= 25) {
            throw BleError.INVALID_PACKAGE_FOR_ENCRYPTION_TOO_SHORT
        }
        
        // copy the nonce over to the class var
        for i in [Int](0...nonce.count-1) {
            nonce[i] = dataArray[i]
        }
        
        
        // only allow 0, 1, 2 for Admin, User, Guest
        if (dataArray[8] > 2) {
            throw BleError.INVALID_KEY_FOR_ENCRYPTION
        }
        
        // get the key from the data
        userLevel = UserLevel(rawValue: Int(dataArray[8]))!
        
        // copy the nonce over to the class var
        for (index,element) in dataArray.enumerate() {
            payloadData[index+9] = element
        }
        
        if (payloadData.count % 16 != 0) {
            throw BleError.INVALID_SIZE_FOR_ENCRYPTED_PAYLOAD
        }
        
        payload = payloadData;
    }
    
    func getPayload() throws -> [UInt8] {
        if (payload != nil) {
            return payload!
        }
        throw BleError.CAN_NOT_GET_PAYLOAD
    }
}
