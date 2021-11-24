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
    let handle: UUID
    var existingIndices: [IndexResultPacket]!
    var dayStartTimeSecondsSinceMidnight : UInt32
    var finalBehaviourList :[Behaviour]!
    
    public init(handle: UUID, bluenet: Bluenet, behaviourDictionaryArray: [NSDictionary], dayStartTimeSecondsSinceMidnight: UInt32) {
        self.handle = handle
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
        return bluenet.behaviour(self.handle).getIndices()
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
        // if they do not exist, we might want to upload them later.
        for behaviour in hasher.behaviours {
            if behaviour.indexOnCrownstone == nil {
                self.finalBehaviourList.append(behaviour)
            }
        }
        
        
        // now we look for new behaviours that do not exist on our behaviour array
        for indexPacket in self.existingIndices {
            var foundIndex = false
            for behaviour in hasher.behaviours {
                if indexPacket.behaviourHash == behaviour.getHash() {
                    // match! Jey! Do nothing!
                    self.finalBehaviourList.append(behaviour)
                    foundIndex = true
                })
                    break
                }
            }
                
            if foundIndex == false {
                // we want to download this behaviour!
                // generate the todo task for the getting of the behaviour
                todo.append({ () in
                    return Promise<Void> { seal in
                        self.bluenet.behaviour(self.handle).getBehaviour(index: indexPacket.index)
                            .done{ (behaviour: Behaviour) -> Void in
                                self.finalBehaviourList.append(behaviour)
                                seal.fulfill(())
                            }
                            .catch { err in seal.reject(err) }
                    }
                })
            }
        }
        
        return promiseBatchPerformer(arr: todo, index: 0)
            .then{ _ -> Promise<[Behaviour]> in return Promise<[Behaviour]> { seal in seal.fulfill(self.finalBehaviourList) }}
    }
    
    
}
