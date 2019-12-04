//
//  BehaviourHasher.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 04/12/2019.
//  Copyright © 2019 Alex de Mulder. All rights reserved.
//

import Foundation


class BehaviourHasher {
    var behaviours : [Behaviour]!
    
    init(_ dictArray: [NSDictionary], dayStartTimeSecondsSinceMidnight: UInt32) {
        behaviours = [Behaviour]()
        for dict in dictArray {
            let behaviour = try? BehaviourDictionaryParser(dict, dayStartTimeSecondsSinceMidnight: dayStartTimeSecondsSinceMidnight)
            if behaviour != nil {
                behaviours.append(behaviour!)
            }
        }
        
        behaviours.sort( by: { a,b in
            if a.indexOnCrownstone != nil && b.indexOnCrownstone != nil {
                return a.indexOnCrownstone! > b.indexOnCrownstone!
            }
            return false
        })
    }
    
    func getMasterHash() -> UInt32 {
        var hashPacket = [UInt8]()
        
        for behaviour in behaviours {
            if behaviour.indexOnCrownstone != nil {
                print("Behaviour index \(behaviour.indexOnCrownstone)")
                hashPacket.append(behaviour.indexOnCrownstone!)
                hashPacket.append(0)
                hashPacket += behaviour.getPaddedPacket()
            }
        }
        
        
        
        return fletcher32(hashPacket)
    }
    
    func compareWithIndexHashes(data: [UInt8]) {
        
    }
    
    
}
