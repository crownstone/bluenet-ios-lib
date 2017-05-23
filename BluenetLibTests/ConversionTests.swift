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



class ConversionTests: XCTestCase {
    
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
        let bitmask32_1 : UInt32 = 0x80000000
        let bitmask32_16 : UInt32 = 0x00010000
        
        var maskAt1 = [Bool](repeating: false, count: 32)
        maskAt1[0] = true;
        let maskAt16 = [
            false,   // 31
            false,   // 30
            false,   // 29
            false,   // 28
            false,   // 27
            false,   // 26
            false,   // 25
            false,   // 24
            false,   // 23
            false,   // 22
            false,   // 21
            false,   // 20
            false,   // 19
            false,   // 18
            false,   // 17
            true,    // 16
            false,   // 15
            false,   // 14
            false,   // 13
            false,   // 12
            false,   // 11
            false,   // 10
            false,   // 9
            false,   // 8
            false,   // 7
            false,   // 6
            false,   // 5
            false,   // 4
            false,   // 3
            false,   // 2
            false,   // 1
            false    // 0
        ]
        XCTAssertEqual(Conversion.uint32_to_bit_array(bitmask32_1),maskAt1)
        XCTAssertEqual(Conversion.uint32_to_bit_array(bitmask32_16),maskAt16)
    }
    
    
}
