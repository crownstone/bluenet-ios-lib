//
//  BehaviourHandler.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 22/10/2019.
//  Copyright © 2019 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth


public class BehaviourHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    
    public func hashBehaviour(behaviour: Behaviour) {
        
    }
    
    
    


    
    
}
