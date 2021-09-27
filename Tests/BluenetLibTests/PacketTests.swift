//
//  PacketTests.swift
//  BluenetLibTests
//
//  Created by Alex de Mulder on 22/01/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

#if !os(watchOS)
import XCTest
import SwiftyJSON
@testable import BluenetLib



class Timetests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testTimePacke(){
        // the time on the Crownstone is GMT + timeoffset (so + 7200s for dutch summer time)
        // we have to do the same when reconstructing it

        let now = Date().timeIntervalSince1970
        let reconstructed = reconstructTimestamp(currentTimestamp: now, LsbTimestamp: 53028)
        print(now, reconstructed, now - reconstructed)
        print(now - getCurrentTimestampForCrownstone())
//        print(Date().timeIntervalSince1970)
//        print(NSNumber(value: TimeZone.current.secondsFromGMT()).doubleValue) // +7200
        
    }
    
    func testControlPackets() {
       
    }
    
    func testMeshPackets() {
       
    }
    
}
#endif
