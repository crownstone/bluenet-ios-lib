//
//  PowerHandler
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

public class PowerHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    var deviceList : [String: AvailableDevice]!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings, deviceList: [String: AvailableDevice]) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
        self.deviceList = deviceList
    }
    
    /**
     * Set the switch state. If 0 or 1, switch on or off. If 0 < x < 1 then dim.
     * TODO: currently only relay is supported.
     */
    public func switchRelay(state: UInt8) -> Promise<Void> {
        print ("------ BLUENET_LIB: switching relay to \(state)")
        let packet : [UInt8] = [state]
        return self.bleManager.writeToCharacteristic(
            CSServices.PowerService,
            characteristicId: PowerCharacteristics.Relay,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse
        )
    }
    
    
    
    public func notifyPowersamples() -> Promise<() -> Promise<Void>> {
        let successCallback = {(data: [UInt8]) -> Void in
            let samples = PowerSamples(data: data)
            if (samples.valid) {
                if (self.bleManager.settings.encryptionEnabled) {
                    
                }
                else {
                    
                }
                
                print("collectedSamples \(samples.current.count) \(samples.voltage.count) \(samples.currentTimes.count) \(samples.voltageTimes.count)")
            }
        }
        let merger = NotificationMerger(callback: successCallback)
        
        let callback = {(data: AnyObject) -> Void in
            if let castData = data as? NSData {
                merger.merge(castData.arrayOfBytes())
            }
        }
        return self.bleManager.enableNotifications(CSServices.PowerService, characteristicId: PowerCharacteristics.PowerSamples, callback: callback)
    }
    

    
    
    
    // MARK : Support functions
    
    
    
}
