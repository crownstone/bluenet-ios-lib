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



class Behaviourtests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testBehaviourHash(){
        // the time on the Crownstone is GMT + timeoffset (so + 7200s for dutch summer time)
        // we have to do the same when reconstructing it
        let allDays = ActiveDays(data: 255)
        let time0 = BehaviourTimeContainer(from: BehaviourTime(hours: 23, minutes: 30), until: BehaviourTime(type: .afterSunrise, offset: UInt32(0)))
        let behaviour0 = Behaviour(profileIndex: 0, type: .twilight, intensity: 20, activeDays: allDays, time: time0)
        behaviour0.indexOnCrownstone = 4
        
        
        let time1 = BehaviourTimeContainer(from: BehaviourTime(hours: 21, minutes: 30), until: BehaviourTime(type: .afterSunrise, offset: UInt32(0)))
        let behaviour1 = Behaviour(profileIndex: 0, type: .twilight, intensity: 40, activeDays: allDays, time: time1)
        behaviour1.indexOnCrownstone = 3
        
        let time2 = BehaviourTimeContainer(from: BehaviourTime(hours: 22, minutes: 30), until: BehaviourTime(type: .afterSunrise, offset: UInt32(0)))
        let behaviour2 = Behaviour(profileIndex: 0, type: .twilight, intensity: 34, activeDays: allDays, time: time2)
        behaviour2.indexOnCrownstone = 0
        
        XCTAssertEqual(behaviour0.getHash(),3862170956)
        XCTAssertEqual(behaviour1.getHash(),3519283504)
        XCTAssertEqual(behaviour2.getHash(),4160490302)
        
        let hasher = BehaviourHasher([behaviour0, behaviour1, behaviour2])
        let hash = hasher.getMasterHash()
        
        XCTAssertEqual(hash, 1839667649)
    }
    
}
#endif
