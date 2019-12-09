//
//  broadcast.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 04/12/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

public class BroadcastHandler {
    let peripheralStateManager : PeripheralStateManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    
    
    init (peripheralStateManager: PeripheralStateManager, eventBus: EventBus, settings: BluenetSettings) {
        self.peripheralStateManager = peripheralStateManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    

    
    public func multiSwitch(referenceId: String, stoneId: UInt8, switchState: Float) -> Promise<Void> {
        return Promise<Void> { seal in
            
            let switchState = NSNumber(value: min(1,max(0,switchState))*100).uint8Value
            let packet  = BroadcastStone_SwitchPacket(crownstoneId: stoneId, state: switchState).getPacket()
            let element = BroadcastElement(referenceId: referenceId, type: .multiSwitch, packet: packet, seal: seal, target: stoneId)
            
            self.peripheralStateManager.loadElement(element: element)
        }
    }
    
    
    /**
     * Method for setting the time on a crownstone
     */
    public func setTime(referenceId: String, time: UInt32? = nil, sunriseSecondsSinceMidnight: UInt32, sunsetSecondsSinceMidnight: UInt32) -> Promise<Void> {
        return Promise<Void> { seal in
            
            var packet : [UInt8]!
            if let customTime = time {
                packet = Broadcast_SetTimePacket(time: customTime, sunrisetSecondsSinceMidnight: sunriseSecondsSinceMidnight, sunsetSecondsSinceMidnight: sunsetSecondsSinceMidnight).getPacket()
            }
            else {
                packet = Broadcast_SetTimePacket(sunrisetSecondsSinceMidnight: sunriseSecondsSinceMidnight, sunsetSecondsSinceMidnight: sunsetSecondsSinceMidnight).getPacket()
            }
            
            
            let element = BroadcastElement(
                referenceId: referenceId,
                type: .setTime,
                packet: packet,
                seal: seal,
                singular: true
            )
            
            self.peripheralStateManager.loadElement(element: element)
        }
    }
    
    
    
    
    
    
}
