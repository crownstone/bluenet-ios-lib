//
//  BehaviourSyncing.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 04/12/2019.
//  Copyright © 2019 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit

// The flow is:
// - We first have to ensure all the things we want to change are changed. After that, we get a master Hash from the Crownstone
// - So we ask the lib for a master hash of the current behaviour db.
// - Check if the master hash from the crownstone matches the local db expected hash
// - If it is not the same, we provide all our behaviours to the lib: to the BehaviourSyncer
// - We assume the user is already connected to the Crownstone
// - Any mismatches mean that our local understanding of the behaviours is incomplete. The data on the Crownstone is leading (assuming all our expected mutations have already been done)

public class BehaviourSyncer {
    let bluenet : Bluenet!
    let hasher : BehaviourHasher!
    var existingIndices: [IndexResultPacket]!
    var dayStartTimeSecondsSinceMidnight : UInt32
    var finalBehaviourList :[Behaviour]!
    
    init(bluenet: Bluenet, behaviourDictionaryArray: [NSDictionary], dayStartTimeSecondsSinceMidnight: UInt32) {
        self.dayStartTimeSecondsSinceMidnight = dayStartTimeSecondsSinceMidnight
        self.bluenet = bluenet
        self.existingIndices = [IndexResultPacket]()
        self.finalBehaviourList = [Behaviour]()
        self.hasher = BehaviourHasher(
            behaviourDictionaryArray,
            dayStartTimeSecondsSinceMidnight: dayStartTimeSecondsSinceMidnight
        )
    }
    
    public func sync() -> Promise<[Behaviour]> {
       return self._getIndices()
           .then{ () in return self._sync() }
    }
    
    func _getIndices() -> Promise<Void> {
        return bluenet.behaviour.getIndices()
            .then{ (_ indexData : [IndexResultPacket]) -> Promise<Void> in
                self._loadIndices(indexData)
                return Promise<Void>{seal in seal.fulfill(())}
            }
    }
    
    func _loadIndices(_ indexData: [IndexResultPacket]) {
        self.existingIndices = indexData
    }
    
    
    
    func _sync() -> Promise<[Behaviour]> {
        var todo = [voidPromiseCallback]()
        
        self.finalBehaviourList = [Behaviour]()
        
        // loop over all behaviours and check if the indices we expect them to have exist on the Crownstone
        // if they exist, check if we need to update our behaviour (if hashes do not match)
        // if they do not exist, remove behaviour from our store
        for behaviour in hasher.behaviours {
            if behaviour.indexOnCrownstone == nil {
                self.finalBehaviourList.append(behaviour)
            }
            else {
                var foundIndex = false
                for indexPacket in self.existingIndices {
                    if indexPacket.index == behaviour.indexOnCrownstone! {
                        if indexPacket.behaviourHash == behaviour.getHash() {
                            // match! Jey! Do nothing!
                            self.finalBehaviourList.append(behaviour)
                        }
                        else {
                            // sync required. Download the behaviour and add that one to the list instead
                            
                            // generate the todo task for the getting of the behaviour
                            todo.append({ () in
                                print("Downloading behaviour \(indexPacket.index) because the hash is different.")
                                return Promise<Void> { seal in
                                    self.bluenet.behaviour.getBehaviour(index: indexPacket.index)
                                        .done{ (behaviour: Behaviour) -> Void in
                                            self.finalBehaviourList.append(behaviour)
                                            seal.fulfill(())
                                        }
                                        .catch { err in seal.reject(err) }
                                }
                            })
                        }
                        foundIndex = true
                        break
                    }
                }
                
                if foundIndex == false {
                    // delete the behaviour from our list. We do this by simply not adding this into the self.finalBehaviourList
                }
            }
        }
        
        
        // now we look for new behaviours that do not exist on our behaviour array
        for indexPacket in self.existingIndices {
            var foundIndex = false
            for behaviour in hasher.behaviours {
                if indexPacket.index == behaviour.indexOnCrownstone! {
                    // it's here! We do not have to do anything. The hash compare has been done above
                    foundIndex = true
                    break
                }
                
                if foundIndex == false {
                    // we want to download this behaviour!
                    // generate the todo task for the getting of the behaviour
                    todo.append({ () in
                        return Promise<Void> { seal in
                            self.bluenet.behaviour.getBehaviour(index: indexPacket.index)
                                .done{ (behaviour: Behaviour) -> Void in
                                    self.finalBehaviourList.append(behaviour)
                                    seal.fulfill(())
                                }
                                .catch { err in seal.reject(err) }
                        }
                    })
                }
            }
        }
        
        return promiseBatchPerformer(arr: todo, index: 0)
            .then{ _ -> Promise<[Behaviour]> in return Promise<[Behaviour]> { seal in seal.fulfill(self.finalBehaviourList) }}
    }
    
    
}
