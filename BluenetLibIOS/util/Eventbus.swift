//
//  Eventbus.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 24/05/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

public class EventBus {
    init() {}
    
    var idCounter : Int = 0
    var subscribers = [Int:    String]()
    var topics      = [String: [Int: eventCallback]]()
    
    func emit(topic: String, _ data: AnyObject) {
        if (self.topics[topic] != nil) {
            for (_ , callback) in self.topics[topic]! {
                callback(data)
            }
        }
    }
    
    func on(topic: String, _ callback: (notification: AnyObject) -> Void) -> voidCallback {
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
    
   
    
    
    func hasListeners(topic: String) -> Bool {
        return (self.topics[topic] != nil)
    }
    
    func reset() {
        self.topics = [String: [Int: eventCallback]]()
        self.subscribers = [Int: String]()
    }
    
    
    // MARK: Util
    
    func _off(id: Int) {
        if (self.subscribers[id] != nil) {
            let topic = self.subscribers[id]!;
            if (self.topics[topic] != nil) {
                // remove callback from topic
                self.topics[topic]!.removeValueForKey(id)
                
                // clean topic if empty
                if (self.topics[topic]!.count == 0) {
                    self.topics.removeValueForKey(topic);
                }
                
                // remove subscriber index
                self.subscribers.removeValueForKey(id);
            }
        }
    }
    
    func _getId() -> Int {
        self.idCounter += 1
        return self.idCounter
    }
}