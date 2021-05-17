//
//  BluenetLibIOSTests.swift
//  BluenetLibIOSTests
//
//  Created by Alex de Mulder on 11/04/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

#if !os(watchOS)
import XCTest
@testable import BluenetLib



class EventBusTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testTimestampConvert() {
        let bus = EventBus()
//        var subscribers = [String: String]()
//        var topics      = [String: [String: eventCallback]]()
        XCTAssertEqual(bus.subscribers.count, 0, "No subscribers")
        XCTAssertEqual(bus.topics.count,      0, "No topics")
        
        let unsub = bus.on("test", { _ in })
        XCTAssertEqual(bus.subscribers.count,       1, "One subscriber")
        XCTAssertEqual(bus.topics.count,            1, "One topic")
        XCTAssertEqual(bus.topics["test"]!.count,   1, "One subscriber in test")
        
        unsub()
        XCTAssertEqual(bus.subscribers.count, 0, "No subscribers")
        XCTAssertEqual(bus.topics.count,      0, "No topics")
    }
}
#endif
