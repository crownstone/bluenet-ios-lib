//
//  Eventbus.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 24/05/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

open class EventBus {
    init() {}
    
    var idCounter : Int = 0
    var subscribers = [Int:    String]()
    var topics      = [String: [Int: eventCallback]]()
    
    func emit(_ topic: String, _ data: Any) {
        if (self.topics[topic] != nil) {
            for (_ , callback) in self.topics[topic]! {
                callback(data)
            }
        }
    }
    
    func on(_ topic: String, _ callback: @escaping (_ notification: Any) -> Void) -> voidCallback {
        if (self.topics[topic] == nil) {
            self.topics[topic] = [Int: eventCallback]()
        }
        let id = self._getId()

        self.subscribers[id] = topic;
        self.topics[topic]![id] = callback
        
        return { _ in
            self._off(id);
        }
    }
    
   
    
    
    func hasListeners(_ topic: String) -> Bool {
        return (self.topics[topic] != nil)
    }
    
    func reset() {
        self.topics = [String: [Int: eventCallback]]()
        self.subscribers = [Int: String]()
    }
    
    
    // MARK: Util
    
    func _off(_ id: Int) {
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
    }
    
    func _getId() -> Int {
        self.idCounter += 1
        return self.idCounter
    }
}
