//
//  Bluenet.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 24/05/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import UIKit
import PromiseKit
import CoreBluetooth

var APPNAME = "Crownstone"
var VIEWCONTROLLER : UIViewController?

//public func parseServiceData(data) -> [String: AnyObject] {
    
//}

public class AvailableDevice {
    var rssiHistory = [Double: Int]()
    var rssi : Int!
    var name : String?
    var uuid : String
    var lastUpdate : Double = 0
    var cleanupCallback : () -> Void
    var avgRssi : Double!
    
    // config
    let timeout : Double = 5 //seconds
    let rssiTimeout : Double = 2 //seconds
    
    init(_ data: Advertisement, _ cleanupCallback: () -> Void) {
        self.name = data.name
        self.uuid = data.uuid
        self.cleanupCallback = cleanupCallback
        self.avgRssi = data.rssi.doubleValue
        self.update(data)
    }
    
    func checkTimeout(referenceTime : Double) {
        // if they are equal, no update has happened since the scheduling of this check.
        if (self.lastUpdate == referenceTime) {
            self.cleanupCallback()
        }
    }
    
    func clearRSSI(referenceTime : Double) {
        self.rssiHistory.removeValueForKey(referenceTime)
        self.calculateRssiAverage()
    }
    
    func update(data: Advertisement) {
        self.rssi = data.rssi.integerValue
        self.lastUpdate = NSDate().timeIntervalSince1970
        self.rssiHistory[self.lastUpdate] = self.rssi;
        self.calculateRssiAverage()
        delay(self.timeout, {_ in self.checkTimeout(self.lastUpdate)});
        delay(self.rssiTimeout, {_ in self.clearRSSI(self.lastUpdate)});
    }
    
    func calculateRssiAverage() {
        var count = 0
        var total : Double = 0
        for (_, rssi) in self.rssiHistory {
            total = total + Double(rssi)
            count += 1
        }
        self.avgRssi = total/Double(count);
    }
}

public func setViewController(viewController: UIViewController) {
    VIEWCONTROLLER = viewController;
}

public class Bluenet {
    // todo: set back to private
    public let bleManager : BleManager!
    let eventBus : EventBus!
    
    var deviceList = [String: AvailableDevice]()
    
    public init(appName: String) {
        self.eventBus = EventBus()
        self.bleManager = BleManager(eventBus: self.eventBus)
        
        self.eventBus.on("advertisementData", self.parseAdvertisement)
        APPNAME = appName
    }
    
    func parseAdvertisement(data: AnyObject) {
        if let castData = data as? Advertisement {
            if deviceList[castData.uuid] != nil {
                deviceList[castData.uuid]!.update(castData)
            }
            else {
                deviceList[castData.uuid] = AvailableDevice(castData, {_ in self.deviceList.removeValueForKey(castData.uuid)})
            }
        }
    }
    
    public func reset() {
        self.eventBus.reset()
    }
    
    public func startScanning() {
        self.bleManager.startScanning()
    }
    
    public func startScanningForCrownstones() {
        self.startScanningForService("C001")
    }
    
    public func startScanningForService(serviceUUID: String) {
        self.bleManager.startScanningForService(serviceUUID)
    }
    
    public func stopScanning() {
        self.bleManager.stopScanning()
    }
    
    public func isReady() -> Promise<Void> {
        return self.bleManager.isReady()
    }
    
    public func connect(uuid: String) -> Promise<Void> {
        return self.bleManager.connect(uuid)
    }
    
    public func disconnect() -> Promise<Void> {
        print("disconnectiong")
       return self.bleManager.disconnect()
    }
    
    public func getBLEstate() -> CBCentralManagerState {
        return self.bleManager.BleState;
    }
    
    
    
    /**
     * Set the switch state. If 0 or 1, switch on or off. If 0 < x < 1 then dim.
     */
    public func setSwitchState(state: Float) -> Promise<Void> {
//        if (state == 0 || state >= 1) {
            print ("switching to \(state)")
            var roundedState = max(0,min(255,round(state*255)))
            var switchState = UInt8(roundedState)
            var packet : [UInt8] = [switchState]
            return self.bleManager.writeToCharacteristic(
                CSServices.PowerService,
                characteristicId: PowerCharacteristics.Relay,
                data: NSData(bytes: packet, length: packet.count),
                type: CBCharacteristicWriteType.WithResponse
            )
//        }
//        else {
//            var switchState = UInt8(state*100.0)
//            return self.bleManager.writeToCharacteristic(
//                CSServices.CrownstoneService,
//                characteristicId: CrownstoneCharacteristics.Control,
//                data: ControlPacket(type: .PWM, payload8: switchState).getNSData(),
//                type: CBCharacteristicWriteType.WithoutResponse
//            )
//        }
    }
    
    public func on(topic: String, _ callback: (AnyObject) -> Void) -> Int {
        return self.eventBus.on(topic, callback)
    }
    
    public func off(id: Int) {
        self.eventBus.off(id);
    }
}

