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
    
    typealias callbackType = (AnyObject) -> Void
    var idCounter : Int = 0
    var subscribers = [Int:    String]()
    var topics      = [String: [Int: callbackType]]()
    
    func emit(topic: String, _ data: AnyObject) {
        if (self.topics[topic] != nil) {
            for (_ , callback) in self.topics[topic]! {
                callback(data)
            }
        }
    }
    
    func on(topic: String, _ callback: (notification: AnyObject) -> Void) -> Int {
        if (self.topics[topic] == nil) {
            self.topics[topic] = [Int: callbackType]()
        }
        let id = self._getId()

        self.subscribers[id] = topic;
        self.topics[topic]![id] = callback
        
        return id
    }
    
    func off(id: Int) {
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
    
    
    func hasListeners(topic: String) -> Bool {
        return (self.topics[topic] != nil)
    }
    
    func reset() {
        self.topics = [String: [Int: callbackType]]()
        self.subscribers = [Int: String]()
    }
    
    
    // MARK: Util
    
    func _getId() -> Int {
        self.idCounter += 1
        return self.idCounter
    }
}