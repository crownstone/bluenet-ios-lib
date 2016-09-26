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
public class Bluenet  {
    // todo: set back to private, currently public for DEBUG
    public let bleManager : BleManager!
    public var settings : BluenetSettings!
    let eventBus : EventBus!
    var deviceList = [String: AvailableDevice]()
    var setupList = [String: NSNumber]()
    
    // declare the classes handling the library protocol
    public let dfu      : DfuHandler!
    public let config   : ConfigHandler!
    public let setup    : SetupHandler!
    public let control  : ControlHandler!
    public let power    : PowerHandler!

    
    // MARK: API
    
    /**
     * We use the appname in the popup messages that can be generated to check if the bluetooth is on and
     * permissions are set correctly.
     */
    public init() {
        self.settings = BluenetSettings()
        self.eventBus = EventBus()
        self.bleManager = BleManager(eventBus: self.eventBus)
        
        // pass on the shared objects to the worker classes
        self.dfu     = DfuHandler(    bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList);
        self.config  = ConfigHandler( bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList);
        self.setup   = SetupHandler(  bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList);
        self.control = ControlHandler(bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList);
        self.power   = PowerHandler(  bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList);

        
        // subscribe to BLE advertisements (TODO: add encryption)
        self.eventBus.on("advertisementData", self._parseAdvertisement)
    }
    
    
    /**
     * Load a settings object into Bluenet
     */
    public func setSettings(settings: BluenetSettings) {
        self.settings = settings
        self.bleManager.setSettings(settings)
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
     * Start actively scanning for Crownstones based on the scan response service uuid.
     * Scan results will be broadcasted on the "advertisementData" topic.
     *
     * This is the battery saving variant, only unique messages are shown.
     */
    public func startScanningForCrownstonesUniqueOnly() {
        self.startScanningForServiceUniqueOnly(CrownstoneAdvertisementServiceUUID)
    }
    
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    public func startScanningForService(serviceUUID: String) {
        self.bleManager.startScanningForService(serviceUUID)
    }
    
    
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic. 
     *
     * This is the battery saving variant, only unique messages are shown.
     */
    public func startScanningForServiceUniqueOnly(serviceUUID: String) {
        self.bleManager.startScanningForServiceUniqueOnly(serviceUUID)
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
            .then({_ -> Promise<Void> in
                return Promise<Void> {fulfill, reject in
                    if (self.settings.isEncryptionEnabled()) {
                        self.control.getAndSetSessionNonce()
                            .then({_ in fulfill()})
                            .error({err in reject(err)})
                    }
                    else {
                        fulfill()
                    }
                }
            });
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
    
    public func waitToReconnect() -> Promise<Void> {
        return self.bleManager.waitToReconnect()
    }
    
    public func waitToWrite() -> Promise<Void> {
        return self.bleManager.waitToWrite()
    }
    
    // MARK: util
    func _parseAdvertisement(data: AnyObject) {
        if let castData = data as? Advertisement {
            if deviceList[castData.handle] != nil {
                deviceList[castData.handle]!.update(castData)
                if (deviceList[castData.handle]!.verified) {
                    self.eventBus.emit("verifiedAdvertisementData",castData)
                    
                    if (castData.rssi.integerValue < 0) {
                        if (castData.isSetupPackage()) {
                            self.setupList[castData.handle] = castData.rssi
                            self._emitNearestSetupCrownstone()
                        }
                        else {
                            self._emitNearestCrownstone();
                            self.setupList.removeValueForKey(castData.handle)
                        }
                    }
                }
            }
            else {
                deviceList[castData.handle] = AvailableDevice(castData, {_ in self.deviceList.removeValueForKey(castData.handle)})
            }
        }
    }
    
    func _emitNearestSetupCrownstone() {
        var nearestRSSI = -1000
        var nearestId = ""
        for (stoneId, rssi) in self.setupList {
            let rssiInt = rssi.integerValue
            if (rssiInt > nearestRSSI) {
                nearestRSSI = rssiInt
                nearestId = stoneId
            }
        }
        if (nearestId != "" && nearestRSSI < 0) {
            let data = NearestItem(handle: nearestId, rssi: nearestRSSI, setupMode: true)
            self.eventBus.emit("nearestSetupCrownstone", data)
        }
    }
    
    func _emitNearestCrownstone() {
        var nearestRSSI = -1000
        var nearestId = ""
        for (stoneId, device) in self.deviceList {
            if (device.rssi > nearestRSSI) {
                nearestRSSI = device.rssi
                nearestId = stoneId
            }
        }
        if (nearestId != "" && nearestRSSI < 0) {
            let data = NearestItem(handle: nearestId, rssi: nearestRSSI, setupMode: false)
            self.eventBus.emit("nearestCrownstone", data)
        }
    }
    
    
}

