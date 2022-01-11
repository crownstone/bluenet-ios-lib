//
//  File.swift
//  
//
//  Created by Alex de Mulder on 05/01/2022.
//
#if !os(watchOS)
import Foundation
import XCTest
import PromiseKit
import SwiftyJSON
@testable import BluenetLib

let queue = DispatchQueue(label: "BleManager") // custom dispatch queues are serial by default

class Que {
    let serialQueue = DispatchQueue(label: "Eventbus") // custom dispatch queues are serial by default

    private let lock = NSRecursiveLock()
    var _tasks = [String: PromiseContainer]()
    
    
    func task(_ handle: String) -> PromiseContainer {
        lock.lock()
        defer { lock.unlock() }
        let uppercaseHandle = handle.uppercased()
        
        if let task = self._tasks[uppercaseHandle] {
        
            return task
        }
        
        let task = PromiseContainer(uppercaseHandle)
        self._tasks[uppercaseHandle] = task
        
        return task
    }
    
    func callQueue() {
        print("before serialQueue.async")
        self.serialQueue.async {
            print("inside serialQueue.async")
        }
        print("after serialQueue.async")
    }
    
    
    var dic = [String: Int]()
    
    init() {
        self.dic["one"] = 1
        self.dic["two"] = 2
        self.dic["three"] = 3
    }
    
    func one() -> Int {
        queue.sync {
            return dic["one"]!
        }
    }
    
    func two() -> Int {
        queue.sync {
            return dic["two"]!
        }
    }
}

let lock = NSRecursiveLock()
func promiseReturner() -> Promise<Int> {
    lock.lock()
    defer { print("unlock"); lock.unlock() }
    defer { print("unlock"); lock.unlock() }
    return Promise<Int> { seal in
        print("created promise")
        delay(0.1, {
            print("return");
            seal.fulfill(1)
        })
        print("finished Promise")
    }
}


class QueueTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testQueue(){
        let a = Que()
        
        DispatchQueue.concurrentPerform(iterations: 1000_000) { i in
            a.task("test").load({},{_ in }, type: .CONNECT)
            a.task("test")._clear()
        }
    }
    
    func testLocksWithPromises() {
        let expected = expectation(description: "callback happened")
        _ = promiseReturner()
            .done { val in print("got \(val)"); expected.fulfill()}
        
        wait(for: [expected], timeout: 1)
    }
    
    func testSerialQueue() {
        let a = Que()
        print("before call")
        a.callQueue()
        print("after call")
    }    
}
    

#endif
