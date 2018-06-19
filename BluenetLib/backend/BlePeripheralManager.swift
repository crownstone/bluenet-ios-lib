//
//  BlePeripheralManager.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 10/04/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth
import CoreLocation
import SwiftyJSON
import PromiseKit

open class BlePeripheralManager: NSObject, CBPeripheralManagerDelegate {
    
    
    open var peripheralManager : CBPeripheralManager!
    
    var pendingPromise : promiseContainer!
    var eventBus : EventBus!
    var notificationEventBus : EventBus!
    open var settings : BluenetSettings!
    
    var decoupledDelegate = false
    
    var BleState : Int = 0
    var backgroundEnabled = true

    var advertising = false
    
    public init(eventBus: EventBus, backgroundEnabled: Bool = true) {
        super.init();
    
        self.settings = BluenetSettings()
        self.eventBus = eventBus
        
        self.backgroundEnabled = backgroundEnabled
    
        
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        // initialize the pending promise containers
        self.pendingPromise = promiseContainer()
    }
    
    public func startAdvertising(uuidString: String) {
        if (self.advertising) {
            self.stopAdvertising()
        }
        self.advertising = true
        let serviceUuid = CBUUID(string: uuidString)
        let serialService = CBMutableService(type: serviceUuid, primary: true)
        
        peripheralManager.add(serialService)
        self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[serviceUuid], CBAdvertisementDataLocalNameKey: APPNAME])
    }
    
    public func startAdvertisingArray(uuidStrings: [String]) {
        if (self.advertising) {
            self.stopAdvertising()
        }
         self.advertising = true
        var serviceUUIDStrings : [CBUUID] = []
        for uuidString in uuidStrings {
            let serviceUuid = CBUUID(string: uuidString)
            let serialService = CBMutableService(type: serviceUuid, primary: true)
            serviceUUIDStrings.append(serviceUuid)
            peripheralManager.add(serialService)
        }
        self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey:serviceUUIDStrings, CBAdvertisementDataLocalNameKey: APPNAME])
    }
    
    public func stopAdvertising() {
        self.advertising = false
        self.peripheralManager.removeAllServices()
        self.peripheralManager.stopAdvertising()
    }
    
    open func isReady() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            if (self.BleState != 5) {
                delay(0.50, { _ = self.isReady().then{_ -> Void in fulfill(())} })
            }
            else {
               fulfill(())
            }
        }
    }
    
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        
    }
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        self.BleState = peripheral.state.rawValue
    }
}
