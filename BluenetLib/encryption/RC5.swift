//
//  RC5.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 19/12/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation



func ROTL(input: UInt16, shift: UInt16) -> UInt16 {
    return (input << shift | input >> (16-shift))
}

func ROTR(input: UInt16, shift: UInt16) -> UInt16 {
    return (input >> shift | input << (16-shift))
}

func RC5ExpandKey(key: [UInt8]) -> [UInt16] {
    // commenting out code that dynamically calculates variables because we will never use different values.
//    let P : UInt16 = 0xB7E1
//    let Q : UInt16 = 0x9E37
//
//    let wordSize = 16
//    let rounds = 12
    let keyLength = 16
    
//    let t = 2*(rounds+1)
//    let c = Int(max(1,ceil(8.0*Double(keyLength)/Double(wordSize))))
//    let u = wordSize/8
    
    // these values are now hardcoded
    let t = 26
    let c = 8
    let u = 2
    var S : [UInt16] = [47073, 22040, 62543, 37510, 12477, 52980, 27947, 2914, 43417, 18384, 58887, 33854, 8821, 49324, 24291, 64794, 39761, 14728, 55231, 30198, 5165, 45668, 20635, 61138, 36105, 11072]
    
    var L = [UInt16](repeating:0, count: c)
//    var S = [UInt16](repeating:0, count: t)
//
//    S[0] = P
//    for i in 1..<t {
//        S[i] = S[i-1] &+ Q
//    }
    
    L[c-1] = 0
    for i in (0...keyLength-1).reversed() {
        L[i/u] = (L[i/u] << 8) + UInt16(key[i])
    }
    
    var i = 0;
    var j = 0
    var k = 0
    var A : UInt16 = 0
    var B : UInt16 = 0
    while (k < 3*t) {
        A = ROTL(input: S[i] &+ A &+ B, shift: 3)
        B = ROTL(input: L[j] &+ A &+ B, shift: (A &+ B) % 16)
        
        S[i] = A
        L[j] = B
        
        
        i = (i+1) % t
        j = (j+1) % c
        k += 1
    }
    
    return S
}



func RC5Encrypt(input: UInt32, key: [UInt8]) -> UInt32 {
    let S = RC5ExpandKey(key: key)
    return RC5Encrypt(input: input, S: S)
}


func RC5Decrypt(input: UInt32, key: [UInt8]) -> UInt32 {
    let S = RC5ExpandKey(key: key)
    return RC5Decrypt(input: input, S: S)
}


func RC5Encrypt(input: UInt32, S: [UInt16]) -> UInt32 {
    let rounds = 12
    
    let inputBytes = Conversion.uint32_to_uint16_reversed_array(input)
    
    var A : UInt16 = inputBytes[0] &+ S[0]
    var B : UInt16 = inputBytes[1] &+ S[1]

    for i in 1...rounds {
        A = ROTL(input: A ^ B, shift: B%16) &+ S[2*i]
        B = ROTL(input: B ^ A, shift: A%16) &+ S[2*i + 1]
    }

    return Conversion.uint16_reversed_array_to_uint32([A,B])
}


func RC5Decrypt(input: UInt32, S: [UInt16]) -> UInt32 {
    let rounds = 12
    let inputBytes = Conversion.uint32_to_uint16_reversed_array(input)
    var A : UInt16 = inputBytes[0]
    var B : UInt16 = inputBytes[1]
 
    for i in (1...rounds).reversed() {
        B = ROTR(input: B &- S[2*i + 1], shift: A%16) ^ A
        A = ROTR(input: A &- S[2*i], shift: B%16) ^ B
        
    }
    return Conversion.uint16_reversed_array_to_uint32([A &- S[0],B &- S[1]])
}



var serviceMap = [
  "B0E4", "14C5", "F0AF", "BF02", "4382", "C1CA", "61A0", "9167", "E042", "589F", "27E4", "AD92", "0DCA", "4F02", "DDC3", "77EA",
  "0970", "99BA", "56AA", "FAB5", "3AE0", "B5BB", "8AE4", "F69D", "E6BC", "EC18", "CA96", "FC91", "A09C", "2A9C", "8EA4", "DBB5",
  "BC67", "63FE", "5DDE", "67B5", "10B4", "1135", "E5CF", "EB4F", "C5DF", "8F29", "1396", "D7BA", "BB0E", "F5DC", "6B07", "20F8",
  "3E6F", "6249", "A567", "85B0", "F994", "15AF", "AB5D", "83B4", "0A96", "F459", "1605", "C8E3", "7E6B", "BA47", "298F", "2B63",
  "D1DB", "35A8", "5A35", "E29E", "42B0", "466A", "1730", "18B9", "5276", "7AE9", "9E83", "DF26", "21C2", "19BB", "D0EB", "4021",
  "0458", "1A3E", "D451", "1B2E", "3D92", "885C", "89C4", "1C23", "53B7", "1D13", "12F5", "1E11", "1FBB", "CE5C", "5FF0", "712F",
  "2216", "47BE", "B47B", "238E", "2412", "26FE", "2502", "8B79", "D811", "2EE0", "2831", "2D94", "9770", "8C3B", "A9D8", "9AF2",
  "2FBB", "30A2", "313A", "E48F", "4ADF", "0B0C", "6FB4", "2C03", "68C4", "86ED", "DE80", "32BB", "E852", "921D", "F8AD", "6619"
]
