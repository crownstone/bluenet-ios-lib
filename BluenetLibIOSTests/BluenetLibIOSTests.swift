//
//  BluenetLibIOSTests.swift
//  BluenetLibIOSTests
//
//  Created by Alex de Mulder on 11/04/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import BluenetLibIOS

func XCTAssertEqualDictionaries<S: Equatable, T: Equatable>(first: [S:T], _ second: [S:T]) {
    XCTAssert(first == second)
}

class BluenetLibIOSTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testConversion() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let uint8Array16 : [UInt8] = [10,32]
        let uint8Array32 : [UInt8] = [10,32,0,2]
        XCTAssertEqual(Conversion.uint8_array_to_uint16(uint8Array16), UInt16(8202))
        XCTAssertEqual(Conversion.uint8_array_to_uint32(uint8Array32), UInt32(33562634))
        XCTAssertEqual(Conversion.uint32_to_int32(UInt32(3147483647)), Int32(-1147483649))
        XCTAssertEqual(Conversion.ibeaconUUIDString_to_uint8_array("b643423e-e175-4af0-a2e4-31e32f729a8a"), [182, 67, 66, 62, 225, 117, 74, 240, 162, 228, 49, 227, 47, 114, 154, 138])
        
        XCTAssertEqual(Conversion.uint8_to_bit_array(53),[true, false, true, false, true, true, false, false])
    }
    
    func testSwift() {
        for (index,element) in [Int](0...5).enumerated() {
            print(index,element)
        }
        
        XCTAssertEqual(3405691582,0xcafebabe)
    }
    
    func testHexString() {
        XCTAssertEqual("FF",String(format:"%2X", 255))
    }
    
    func testJSON() {
        let a = JSON.parse("{\"a\":null}")
        print(a["a"].string)
    }
    
    func testIBeacon() {
        let a = Conversion.ibeaconUUIDString_to_reversed_uint8_array("782995c1-4f88-47dc-8cc1-426a520ec57f")
        print(a)
        let aInv = a.reversed() as [UInt8]
        print(Conversion.uint8_array_to_hex_string(aInv))
    }
    
    func testFingerprint() {
        var a = Fingerprint()
        var b = [iBeaconPacket]()
        
        b.append(iBeaconPacket(uuid: "782995c1-4f88-47dc-8cc1-426a520ec57f", major: 1, minor: 2, distance: 3, rssi: -12, referenceId: "test"))
        b.append(iBeaconPacket(uuid: "782995c1-4f88-47dc-8cc1-426a520ec57f", major: 5, minor: 2, distance: 3, rssi: -32, referenceId: "test"))
        
        a.collect(b)
        a.collect(b)
        a.collect(b)
        a.collect(b)
        
        let c = a.stringify()
        print("A STRINGIFIED: \(c)")
        
        let d = Fingerprint(stringifiedData: c)
        
        XCTAssertEqual(c,d.stringify())
        let x : [String: [NSNumber]] = ["782995c1-4f88-47dc-8cc1-426a520ec57f.Maj:5.Min:2": [-32, -32, -32, -32], "782995c1-4f88-47dc-8cc1-426a520ec57f.Maj:1.Min:2": [-12, -12, -12, -12]]
        let y = NaiveBayes._translateFingerPrint(a)
        var success = true
        
        for (id, _) in x {
            if (y[id] == nil) {
                success = false
            }
            else {
                XCTAssertEqual(x[id]!, y[id]!)
            }
        }
        XCTAssertEqual(success, true)
    }
}
