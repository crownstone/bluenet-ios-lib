//
//  BluenetLibIOSTests.swift
//  BluenetLibIOSTests
//
//  Created by Alex de Mulder on 11/04/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import BluenetLib

func XCTAssertEqualDictionaries<S: Equatable, T: Equatable>(first: [S:T], _ second: [S:T]) {
    XCTAssert(first == second)
}

class BluenetLibTests: XCTestCase {
    
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

        XCTAssertEqual(Conversion.uint16_to_uint8_array(MeshCommandType.config.rawValue),[2 as UInt8, 0 as UInt8])
        XCTAssertEqual(Conversion.uint8_array_to_uint16(uint8Array16), UInt16(8202))
        XCTAssertEqual(Conversion.uint8_array_to_uint32(uint8Array32), UInt32(33562634))
        XCTAssertEqual(Conversion.uint32_to_int32(UInt32(3147483647)), Int32(-1147483649))
        XCTAssertEqual(Conversion.ibeaconUUIDString_to_uint8_array("b643423e-e175-4af0-a2e4-31e32f729a8a"), [182, 67, 66, 62, 225, 117, 74, 240, 162, 228, 49, 227, 47, 114, 154, 138])
        XCTAssertEqual("test".count, 4)
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
        let a = JSON("{\"a\":null}")
        print(a["a"].string)
    }
    
    func testIBeacon() {
        let a = Conversion.ibeaconUUIDString_to_reversed_uint8_array("782995c1-4f88-47dc-8cc1-426a520ec57f")
        print(a)
        let aInv = a.reversed() as [UInt8]
        print(Conversion.uint8_array_to_hex_string(aInv))
    }
    
    
    
    func testScheduleConfig() {
        let config = ScheduleConfigurator(
            scheduleEntryIndex: 0,
            startTime: 1499903011,
            switchState: 1.0
        )
        
        config.fadeDuration = 0
        config.intervalInMinutes = 0
        config.override.location = false
        config.repeatDay.Monday = true
        config.repeatDay.Tuesday = true
        config.repeatDay.Wednesday = true
        config.repeatDay.Thursday = true
        config.repeatDay.Friday = true
        config.repeatDay.Saturday = false
        config.repeatDay.Sunday = false
        
        
        print("packet: \(config.getPacket())")
        print("repeatType: \(config.repeatType)")
        print("actionType: \(config.actionType)")
        print("override.getMask(): \(config.override.getMask())")
        print("repeatDay(): \(config.repeatDay.getMask())")
       
        let x = 0x01
        print("self.repeatType = \(x & 0x0f)")
        print("actionType = \((x >> 4) & 0x0f)")
        
    }
    
}
