//
//  BluenetLibIOSTests.swift
//  BluenetLibIOSTests
//
//  Created by Alex de Mulder on 11/04/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import XCTest

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
        
        XCTAssertEqual(Conversion.uint8_to_bit_array(53),[false, false, true, true, false, true, false, true])
    }
    
    func testSwift() {
        for (index,element) in [Int](0...5).enumerate() {
            print(index,element)
        }
        
        XCTAssertEqual(3405691582,0xcafebabe)
    }
    
    func testHexString() {
        XCTAssertEqual("FF",String(format:"%2X", 255))
    }
}
