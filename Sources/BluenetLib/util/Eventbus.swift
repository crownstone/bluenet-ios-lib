//
//  Eventbus.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 24/05/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

let serialQueue = DispatchQueue(label: "Eventbus") // custom dispatch queues are serial by default


public class EventBus {
    let semaphore = DispatchSemaphore(value: 1)
    var subscribers = [String: String]()
    var topics      = [String: [String: eventCallback]]()
    
    public init() {}
   
    
    public func emit(_ topic: String, _ data: Any) {
        // this is a queue so an emit will not trigger another emit as a nested event.
        serialQueue.async {
            if let topicset = self.topics[topic] {
                for (_ , callback) in topicset {
                    callback(data)
                }
            }
        }
    }
    
    public func on(_ topic: String, _ callback: @escaping (_ notification: Any) -> Void) -> voidCallback {
        let id = getUUID()
        self.semaphore.wait()
        serialQueue.async {
            if (self.topics[topic] == nil) {
                self.topics[topic] = [String: eventCallback]()
            }
            
            self.subscribers[id] = topic;
            self.topics[topic]![id] = callback
            
            self.semaphore.signal()
        }
        return {
            self._off(id);
        }
    }
        
    public func hasListeners(_ topic: String) -> Bool {
        self.semaphore.wait()
        let hasListenersOnTopic = (self.topics[topic] != nil)
        self.semaphore.signal()
        return hasListenersOnTopic
    }
    
    public func reset() {
        self.semaphore.wait()
        serialQueue.async {
            self.topics = [String: [String: eventCallback]]()
            self.subscribers = [String: String]()
            self.semaphore.signal()
        }
    }
    
    
    // MARK: Util
    
    func _off(_ id: String) {
        self.semaphore.wait()
        serialQueue.async {
            if (self.subscribers[id] != nil) {
                let topic = self.subscribers[id]!;
                if (self.topics[topic] != nil) {
                    // remove callback from topic
                    self.topics[topic]!.removeValue(forKey: id)
                    
                    // clean topic if empty
                    if (self.topics[topic]!.count == 0) {
                        self.topics.removeValue(forKey: topic);
                    }
                    
                    // remove subscriber index
                    self.subscribers.removeValue(forKey: id);
                }
            }
            self.semaphore.signal()
        }
    }
}
