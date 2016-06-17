//
//  Bluenet.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 24/05/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth



/**
 * Bluenet.
 * This lib is used to interact with the Crownstone family of devices.
 * There are convenience methods that wrap the corebluetooth backend as well as 
 * methods that simplify the services and characteristics.
 *
 * With this lib you can setup, pair, configure and control the Crownstone family of products.
 
 * This lib broadcasts the following data:
     topic:                      dataType:             when:
     "advertisementData"         Advertisement         When an advertisment packet is received
 */
public class Bluenet {
    // todo: set back to private, currently public for DEBUG
    public let bleManager : BleManager!
    let eventBus : EventBus!
    var deviceList = [String: AvailableDevice]()
    
    // MARK: API
    
    
    /**
     * We use the appname in the popup messages that can be generated to check if the bluetooth is on and
     * permissions are set correctly.
     */
    public init() {
        self.eventBus = EventBus()
        self.bleManager = BleManager(eventBus: self.eventBus)
        
        self.eventBus.on("advertisementData", self._parseAdvertisement)

    }
    
    
    /**
     * Start actively scanning for BLE devices.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    public func startScanning() {
        self.bleManager.startScanning()
    }
    
    
    /**
     * Start actively scanning for Crownstones based on the scan response service uuid.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    public func startScanningForCrownstones() {
        self.startScanningForService(CrownstoneAdvertisementServiceUUID)
    }
    
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    public func startScanningForService(serviceUUID: String) {
        self.bleManager.startScanningForService(serviceUUID)
    }
    
    
    /**
     * Stop actively scanning for BLE devices.
     */
    public func stopScanning() {
        self.bleManager.stopScanning()
    }
    
    
    /**
     * Returns if the BLE manager is initialized. 
     * Should be used to make sure commands are not send before it's finished and get stuck.
     */
    public func isReady() -> Promise<Void> {
        return self.bleManager.isReady()
    }
    
    
    /**
     * Connect to a BLE device with the provided UUID.
     * This UUID is unique per BLE device per iOS device and is NOT the MAC address.
     * Timeout is set to 3 seconds starting from the actual start of the connection. 
     *   - It will abort other pending connection requests
     *   - It will disconnect from a connected device if that is the case
     */
    public func connect(uuid: String) -> Promise<Void> {
        return self.bleManager.connect(uuid)
    }

    
    /**
     * Disconnect from the connected device. Will also fulfil if there is nothing connected.
     * Timeout is set to 2 seconds.
     */
    public func disconnect() -> Promise<Void> {
       return self.bleManager.disconnect()
    }
    
    
    /**
     * Debug.
     */
    public func getBLEstate() -> CBCentralManagerState {
        return self.bleManager.BleState;
    }
    
    
    /**
     * Set the switch state. If 0 or 1, switch on or off. If 0 < x < 1 then dim.
     * TODO: currently only relay is supported.
     */
    public func setSwitchState(state: NSNumber) -> Promise<Void> {
        print ("switching to \(state)")
        var roundedState = max(0, min(255, round(state.doubleValue * 255)))
        var switchState = UInt8(roundedState)
        var packet : [UInt8] = [switchState]
        return self.bleManager.writeToCharacteristic(
            CSServices.PowerService,
            characteristicId: PowerCharacteristics.Relay,
            data: NSData(bytes: packet, length: packet.count),
            type: CBCharacteristicWriteType.WithResponse
        )
    }
    
    
    /**
     * Subscribe to a topic with a callback. This method returns an Int which is used as identifier of the subscription.
     * This identifier is supplied to the off method to unsubscribe.
     */
    public func on(topic: String, _ callback: (AnyObject) -> Void) -> Int {
        return self.eventBus.on(topic, callback)
    }
    
    
    /**
     * Unsubscribe from a subscription.
     * This identifier is obtained as a return of the on() method.
     */
    public func off(id: Int) {
        self.eventBus.off(id);
    }
    
    // MARK: util
    
    func _parseAdvertisement(data: AnyObject) {
        if let castData = data as? Advertisement {
            if deviceList[castData.uuid] != nil {
                deviceList[castData.uuid]!.update(castData)
            }
            else {
                deviceList[castData.uuid] = AvailableDevice(castData, {_ in self.deviceList.removeValueForKey(castData.uuid)})
            }
        }
    }
    
    // TODO: returning device list
    // TODO: other charactertics and services

}

