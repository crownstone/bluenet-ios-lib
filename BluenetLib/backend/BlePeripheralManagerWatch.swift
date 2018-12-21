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
    
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        LOG.info("BLUENET_LIB: Peripheral manager WILL RESTORE STATE \(dict)");
    }
    
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        self.BleState = peripheral.state.rawValue
    }
}
//
//
//public class BlePeripheralManager: NSObject, CBPeripheralManagerDelegate {
//
//    public var peripheralManager : CBPeripheralManager!
//
//    var pendingPromise : promiseContainer!
//    var eventBus : EventBus!
//    var notificationEventBus : EventBus!
//    public var settings : BluenetSettings!
//
//    var decoupledDelegate = false
//
//    var BleState : Int = 0
//    var backgroundEnabled = true
//
//    var advertising = false
//    var restartRequired = false
//
//    public init(eventBus: EventBus, backgroundEnabled: Bool = true) {
//        super.init();
//
//        self.settings = BluenetSettings()
//        self.eventBus = eventBus
//
//        self.backgroundEnabled = backgroundEnabled
//
//        print("Init watch Manager")
//
//        self.peripheralManager = CBPeripheralManager()
//
//
//        // initialize the pending promise containers
//        self.pendingPromise = promiseContainer()
//    }
//
//
//    public func startAdvertisingArray(uuidStrings: [String]) {
//        if (self.advertising) {
//            self.stopAdvertising()
//        }
//        self.advertising = true
//        var serviceUUIDStrings : [CBUUID] = []
//        for uuidString in uuidStrings {
//            let serviceUuid = CBUUID(string: uuidString)
//            serviceUUIDStrings.append(serviceUuid)
//        }
//        self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey:serviceUUIDStrings, CBAdvertisementDataLocalNameKey: APPNAME])
//    }
//
//    public func startAdvertisingDataViaLargeServiceUUID() {
//        let uuidStrings = ["68753A44-4D6F-1226-9C60-0050E4C00067","C001","abcd","ef01","df0d"]
//        var serviceUUIDStrings : [CBUUID] = []
//        for uuidString in uuidStrings {
//            let serviceUuid = CBUUID(string: uuidString)
//            serviceUUIDStrings.append(serviceUuid)
//        }
//        self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey:serviceUUIDStrings])
//    }
//
//    public func startAdvertisingDataViaiBeacon() {
//        let input = "1234567890abcdef1234567890abcdef1122334455"
//        let data = Conversion.hex_string_to_uint8_array(input)
//
//        let nsDataObject = Data(bytes: UnsafePointer<UInt8>(data), count: data.count)
//        let customData = ["kCBAdvDataAppleBeaconKey": nsDataObject]
//
//        self.peripheralManager.startAdvertising(customData)
//    }
//
//    public func stopAdvertising() {
//        self.advertising = false
//        self.peripheralManager.removeAllServices()
//        self.peripheralManager.stopAdvertising()
//    }
//
//    public func isReady() -> Promise<Void> {
//        print("Checking watch is ready")
//        return Promise<Void> { seal in
//            print("self.BleState", self.BleState)
//            if (self.BleState != 5) {
//                delay(0.50, { _ = self.isReady().done{_ -> Void in seal.fulfill(())} })
//            }
//            else {
//                seal.fulfill(())
//            }
//        }
//    }
//
//
//    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
//
//    }
//
//    public func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
//        LOG.info("BLUENET_LIB: Peripheral manager WILL RESTORE STATE \(dict)");
//    }
//
//
//    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
//        self.BleState = peripheral.state.rawValue
//    }
//}
