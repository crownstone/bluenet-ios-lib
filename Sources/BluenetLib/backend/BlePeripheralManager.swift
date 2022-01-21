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

#if os(iOS)
class BlePeripheralManager: NSObject, CBPeripheralManagerDelegate {
    var peripheralManager : CBPeripheralManager? = nil
    var decoupledDelegate = false
    var BleState : Int = 0
    var advertising = false
    var eventBus : EventBus!
 
    init(eventBus: EventBus) {
        self.eventBus = eventBus
        
        super.init()
    }
    
    public func startPeripheral() {
        if (self.peripheralManager == nil) {
            self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
    }
    
    public func startAdvertisingArray(uuidStrings: [String]) {
        var serviceUUIDStrings : [CBUUID] = []
        for uuidString in uuidStrings {
            let serviceUuid = CBUUID(string: uuidString)
            serviceUUIDStrings.append(serviceUuid)
        }
        
        self.startAdvertisingArray(uuids: serviceUUIDStrings)
    }
    
    public func checkBroadcastAuthorization() -> String {
        let status = CBPeripheralManager.authorizationStatus()
        var statusStr = "unknown"
        switch status {
            case .notDetermined:
                eventBus.emit("bleBroadcastStatus", "notDetermined")
                statusStr = "notDetermined"
            case .restricted:
                eventBus.emit("bleBroadcastStatus", "restricted")
                statusStr = "restricted"
            case .denied:
                eventBus.emit("bleBroadcastStatus", "denied")
                statusStr = "denied"
            case .authorized:
                eventBus.emit("bleBroadcastStatus", "authorized")
                statusStr = "authorized"
        }
        
        return statusStr
    }
    
    public func startAdvertisingArray(uuids: [CBUUID]) {
        if (self.advertising) {
            self.stopAdvertising()
        }
        self.advertising = true
        
        if self.peripheralManager == nil {
            self.startPeripheral()
        }
        

        var authorizationState : Int = 0
        if #available(iOS 13.1, *) {
            authorizationState = CBPeripheralManager.authorization.rawValue
        } else {
            // Fallback on earlier versions
            authorizationState = CBPeripheralManager.authorizationStatus().rawValue
        }
        
        if (authorizationState != 3) {
            _ = self.checkBroadcastAuthorization()
        }
        
        self.peripheralManager!.startAdvertising([CBAdvertisementDataServiceUUIDsKey:uuids])
        
    }
    
    
    public func stopAdvertising() {
        self.advertising = false
        
        if self.peripheralManager != nil {
            self.peripheralManager!.removeAllServices()
            self.peripheralManager!.stopAdvertising()
        }
    }
    
    
    public func isReady() -> Promise<Void> {
        return Promise<Void> { seal in
            if (self.BleState != 5) {
                delay(0.50, { _ = self.isReady().done{_ -> Void in seal.fulfill(())} })
            }
            else {
               seal.fulfill(())
            }
        }
    }
    

    public func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        LOG.info("BluenetBroadcast: peripheralManagerStarting willRestoreState \(dict)")
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, error: Error?) {
        LOG.info("BluenetBroadcast: peripheralManager error \(error)")
    }
    
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        self.BleState = peripheral.state.rawValue
    }

}

#endif

#if os(watchOS)
class BlePeripheralManager: NSObject, CBPeripheralManagerDelegate {
    var peripheralManager : CBPeripheralManager!
    var decoupledDelegate = false
    var BleState : Int = 0
    var advertising = false
    
    public override init() {
        super.init();
        self.peripheralManager = CBPeripheralManager()
    }
    
    
    public func startAdvertisingArray(uuidStrings: [String]) {
        var serviceUUIDStrings : [CBUUID] = []
        for uuidString in uuidStrings {
            let serviceUuid = CBUUID(string: uuidString)
            serviceUUIDStrings.append(serviceUuid)
        }
        self.startAdvertisingArray(uuids: serviceUUIDStrings)
    }
    
    public func startAdvertisingArray(uuids: [CBUUID]) {
        if (self.advertising) {
            self.stopAdvertising()
        }
        self.advertising = true
        self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey:uuids, CBAdvertisementDataLocalNameKey: APPNAME])
    }
    
    
    public func stopAdvertising() {
        self.advertising = false
        self.peripheralManager.removeAllServices()
        self.peripheralManager.stopAdvertising()
    }
    
    
    public func isReady() -> Promise<Void> {
        return Promise<Void> { seal in
            if (self.BleState != 5) {
                delay(0.50, { _ = self.isReady().done{_ -> Void in seal.fulfill(())} })
            }
            else {
                seal.fulfill(())
            }
        }
    }
    
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        
    }
    
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        self.BleState = peripheral.state.rawValue
    }
}
#endif

