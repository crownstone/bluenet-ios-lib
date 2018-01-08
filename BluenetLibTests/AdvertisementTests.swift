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



class AdvertisementTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testTimestamp() {
        let currentTimestamp : UInt32 = 1515426625
        let LSB_timestamp : UInt16 = NSNumber(value: currentTimestamp % (0xFFFF+1)).uint16Value
        let currentDouble = NSNumber(value: currentTimestamp).doubleValue
        let restoredTimestamp = BluenetLib.reconstructTimestamp(currentTimestamp : currentDouble, LsbTimestamp: LSB_timestamp)
        XCTAssertEqual(currentDouble, restoredTimestamp)
    }
    
    func testTimestamp2() {
        let currentTimestamp : Double = 0x5A53FFFF + 1
        let LSB_timestamp : UInt16 = 0xFFFF
        let restored = BluenetLib.reconstructTimestamp(currentTimestamp: currentTimestamp, LsbTimestamp: LSB_timestamp)
        XCTAssertEqual(currentTimestamp, restored+1)
    }
    
    func testTimestamp3() {
        let currentTimestamp : Double = 0x5A530000 - 1
        let LSB_timestamp : UInt16 = 0x0000
        let restored = BluenetLib.reconstructTimestamp(currentTimestamp: currentTimestamp, LsbTimestamp: LSB_timestamp)
        XCTAssertEqual(currentTimestamp, restored-1)
    }   
}