//
//  Bluenet.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 24/05/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import UIKit

var APPNAME = "Crownstone"
var VIEWCONTROLLER : UIViewController?

public class Bluenet {
    let bleManager : BleManager!
    let eventBus : EventBus!
    
    public init(viewController: UIViewController, appName: String) {
        self.eventBus = EventBus()
        self.bleManager = BleManager(eventBus: self.eventBus)
        
        APPNAME = appName
        VIEWCONTROLLER = viewController;
    }
    
    
    func connect(uuid: NSUUID) {
    
    }
    
    func disconnect(uuid: NSUUID) {
        
    }
    
    func getBLEstate() -> String {
        return self.bleManager.BleState;
    }
    
    func setSwitchState(state: Float) {
        
    }    
    
    func on(topic: String, _ callback: (AnyObject) -> Void) -> Int {
        return self.eventBus.on(topic, callback)
    }
    
    func off(id: Int) {
        self.eventBus.off(id);
    }
}

