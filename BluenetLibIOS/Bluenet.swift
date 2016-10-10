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


public typealias voidCallback = () -> Void
public typealias voidPromiseCallback = () -> Promise<Void>
public typealias eventCallback = (Any) -> Void

/**
 * Bluenet.
 * This lib is used to interact with the Crownstone family of devices.
 * There are convenience methods that wrap the corebluetooth backend as well as 
 * methods that simplify the services and characteristics.
 *
 * With this lib you can setup, pair, configure and control the Crownstone family of products.
 
 * This lib broadcasts the following data:
   |  topic:                        |     dataType:        |     when:
   |  --------------------------------------------------------------------------------------------------------
   |  "setupProgress"               |     NSNumber         |     Phases in the setup process, numbers from 1 - 13, 0 for error.
   |  "advertisementData"           |     Advertisement    |     When an advertisement packet is received
   |  "verifiedAdvertisementData"   |     Advertisement    |     When an advertisement has been decrypted successfully 3 consecutive times it is verified.
   |                                |                      |     Setup and DFU are also included since they dont need to be decrypted. This sorts out only your Crownstones.
   |  "nearestSetupCrownstone"      |     NearestItem      |     When a verified advertisement packet in setup mode is received, we check the list
   |                                |                      |     of available stones in setup mode and return the closest.
   |  "nearestCrownstone"           |     NearestItem      |     When a verified advertisement packet in setup mode is received, we check the list
   |                                |                      |     of available stones in setup mode and return the closest.
 */
open class Bluenet  {
    // todo: set back to private, currently public for DEBUG
    open let bleManager : BleManager!
    open var settings : BluenetSettings!
    let eventBus : EventBus!
    var deviceList = [String: AvailableDevice]()
    var setupList = [String: NearestItem]()

    // declare the classes handling the library protocol
    open let dfu      : DfuHandler!
    open let config   : ConfigHandler!
    open let setup    : SetupHandler!
    open let control  : ControlHandler!
    open let power    : PowerHandler!

    
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
        _ = self.eventBus.on("advertisementData", self._parseAdvertisement)
    }
    
    
    /**
     * Load a settings object into Bluenet
     */
    open func setSettings(encryptionEnabled: Bool, adminKey: String?, memberKey: String?, guestKey: String?) {
        let settings = BluenetSettings(encryptionEnabled: encryptionEnabled, adminKey: adminKey, memberKey: memberKey, guestKey: guestKey)
        self.settings = settings
        self.bleManager.setSettings(settings)
    }
    
    
    
    
    /**
     * Start actively scanning for BLE devices.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    open func startScanning() {
        self.bleManager.stopScanning()
        self.bleManager.startScanning()
    }
    
    
    /**
     * Start actively scanning for Crownstones based on the scan response service uuid.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    open func startScanningForCrownstones() {
        self.startScanningForService(CrownstoneAdvertisementServiceUUID)
    }
    
    
    /**
     * Start actively scanning for Crownstones based on the scan response service uuid.
     * Scan results will be broadcasted on the "advertisementData" topic.
     *
     * This is the battery saving variant, only unique messages are shown.
     */
    open func startScanningForCrownstonesUniqueOnly() {
        self.startScanningForServiceUniqueOnly(CrownstoneAdvertisementServiceUUID)
    }
    
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    open func startScanningForService(_ serviceUUID: String) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForService(serviceUUID)
    }
    
    
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic. 
     *
     * This is the battery saving variant, only unique messages are shown.
     */
    open func startScanningForServiceUniqueOnly(_ serviceUUID: String) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForServiceUniqueOnly(serviceUUID)
    }
    
    
    /**
     * Stop actively scanning for BLE devices.
     */
    open func stopScanning() {
        self.bleManager.stopScanning()
    }
    
    
    /**
     * Returns if the BLE manager is initialized.
     * Should be used to make sure commands are not send before it's finished and get stuck.
     */
    open func isReady() -> Promise<Void> {
        return self.bleManager.isReady()
    }
    
    
    /**
     * Connect to a BLE device with the provided UUID.
     * This UUID is unique per BLE device per iOS device and is NOT the MAC address.
     * Timeout is set to 3 seconds starting from the actual start of the connection.
     *   - It will abort other pending connection requests
     *   - It will disconnect from a connected device if that is the case
     */
    open func connect(_ uuid: String) -> Promise<Void> {
        return self.bleManager.connect(uuid)
            .then{_ -> Promise<Void> in
                return Promise<Void> {fulfill, reject in
                    if (self.settings.isEncryptionEnabled()) {
                        self.control.getAndSetSessionNonce()
                            .then{_ in fulfill()}
                            .catch{err in reject(err)}
                    }
                    else {
                        fulfill()
                    }
                }
            };
    }
    
    
    /**
     * Disconnect from the connected device. Will also fulfil if there is nothing connected.
     * Timeout is set to 2 seconds.
     */
    open func disconnect() -> Promise<Void> {
        return self.bleManager.disconnect()
    }
    
    
    /**
     * Get the state of the BLE controller.
     */
    open func isBleOff() -> CBCentralManagerState {
        return self.bleManager.BleState;
    }
    
    
    /**
     * Subscribe to a topic with a callback. This method returns an Int which is used as identifier of the subscription.
     * This identifier is supplied to the off method to unsubscribe.
     */
    open func on(_ topic: String, _ callback: @escaping eventCallback) -> voidCallback {
        return self.eventBus.on(topic, callback)
    }
    
    
    open func waitToReconnect() -> Promise<Void> {
        return self.bleManager.waitToReconnect()
    }
    
    open func waitToWrite(_ iteration: UInt8?) -> Promise<Void> {
        return self.bleManager.waitToWrite(iteration)
    }
    
    // MARK: util
    func _parseAdvertisement(_ data: Any) {
        if let castData = data as? Advertisement {
            if deviceList[castData.handle] != nil {
                deviceList[castData.handle]!.update(castData)
                if (deviceList[castData.handle]!.verified) {
                    self.eventBus.emit("verifiedAdvertisementData",castData)
                    
                    if (castData.rssi.intValue < 0) {
                        if (castData.isSetupPackage()) {
                            self.setupList[castData.handle] = NearestItem(name: castData.name, handle: castData.handle, rssi: castData.rssi.intValue, setupMode: true)
                            self._emitNearestSetupCrownstone()
                        }
                        else {
                            self._emitNearestCrownstone(topic: "nearestCrownstone", verifiedOnly: true);
                            self.setupList.removeValue(forKey: castData.handle)
                        }
                    }
                }
                else {
                    self._emitNearestCrownstone(topic: "nearestItem", verifiedOnly: false);
                }
            }
            else {
                deviceList[castData.handle] = AvailableDevice(castData, {_ in self.deviceList.removeValue(forKey: castData.handle)})
            }
        }
    }
    
    func _emitNearestSetupCrownstone() {
        var nearestRSSI = -1000
        var nearestHandle = ""
        var nearestName = ""
        for (handle, nearestItem) in self.setupList {
            if (nearestItem.rssi > nearestRSSI) {
                nearestRSSI = nearestItem.rssi
                nearestHandle = nearestItem.handle
                nearestName = nearestItem.name
            }
        }
        if (nearestHandle != "" && nearestRSSI < 0) {
            let data = NearestItem(name: nearestName, handle: nearestHandle, rssi: nearestRSSI, setupMode: true)
            self.eventBus.emit("nearestSetupCrownstone", data)
        }
    }
    
    func _emitNearestCrownstone(topic: String, verifiedOnly: Bool = true) {
        var nearestRSSI = -1000
        var nearestHandle = ""
        var nearestName : String?
        for (handle, device) in self.deviceList {
            if (device.rssi > nearestRSSI) {
                if (verifiedOnly == true && device.verified == true || verifiedOnly == false) {
                    nearestRSSI = device.rssi
                    nearestHandle = handle
                    nearestName = device.name
                }
            }
        }
        
        if (nearestName == nil) {
            nearestName = "nil"
        }
        
        if (nearestHandle != "" && nearestRSSI < 0) {
            let data = NearestItem(name: nearestName!, handle: nearestHandle, rssi: nearestRSSI, setupMode: false)
            self.eventBus.emit(topic, data)
        }
    }
    
    
}

