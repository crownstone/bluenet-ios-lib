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
        /*
        let proximityUUID = UUID(uuidString:
            "39ED98FF-2900-441A-802F-9C398FC199D2")
        let major : CLBeaconMajorValue = 1
        let minor : CLBeaconMinorValue = 1
        let beaconID = "com.example.myDeviceRegion"
        
        var beacon = CLBeaconRegion(proximityUUID: proximityUUID!, major: major, minor: minor, identifier: beaconID)
        let data : Data = Data(bytes:[2,12,13,14,15,6,7,8,9,10,11,12,13,14,15,16])
        let ibeaconData = beacon.peripheralData(withMeasuredPower: -50)
        var ibeaconDict = ((ibeaconData as NSDictionary) as! [String : Any])
        var manually = [
            "kCBAdvDataAppleBeaconKey": Data(bytes:[0x39, 0xed, 0x98, 0xff, 0x29, 0x00, 0x44, 0x1a, 0x80, 0x2f, 0x9c, 0x39, 0x8f, 0xc1, 0x99, 0xd, 0x00, 0x64, 0x00, 0x01, 0xc5])
        ]
        //ibeaconDict[CBAdvertisementDataServiceUUIDsKey] = [data, Data(bytes:[8,9])]
        print("APPENDED", ibeaconDict)
        print("MANUALLY", manually)
        //self.peripheralManager.add(CBMutableService(type: CBUUID(data: data), primary: true))
        
        */
        self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[serviceUuid], CBAdvertisementDataLocalNameKey: "Fred"])
    }
    
    public func stopAdvertising() {
        self.advertising = false
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
        print("START ADV", error as Any)
    }
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        self.BleState = peripheral.state.rawValue
    }
}
