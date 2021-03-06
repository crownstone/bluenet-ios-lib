//
//  BlePeripheralManagerWatch.swift
//  BluenetWatch
//
//  Created by Alex de Mulder on 12/11/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth
import CoreLocation
import SwiftyJSON
import PromiseKit


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
