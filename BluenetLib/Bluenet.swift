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
   |  "bleStatus"                   |     String           |     Is emitted when the state of the BLE changes. Possible values: "unauthorized", "poweredOff", "poweredOn", "unknown"
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
    var counter : UInt64 = 0
    open let bleManager : BleManager!
    open var settings : BluenetSettings!
    let eventBus : EventBus!
    var deviceList = [String: AvailableDevice]()
    var setupList = [String: NearestItem]()
    var dfuList = [String: NearestItem]()
    var disconnectCommandTimeList = [String: Double]()

    // declare the classes handling the library protocol
    open let dfu      : DfuHandler!
    open let config   : ConfigHandler!
    open let setup    : SetupHandler!
    open let control  : ControlHandler!
    open let power    : PowerHandler!
    open let mesh     : MeshHandler!
    open let device   : DeviceHandler!
    open let state    : StateHandler!

    
    // MARK: API
    /**
     *
     * BackgroundEnabled is passed to the BLE Central Manager. If backgroundEnabled is true:
       - it will have a restoration token (CBCentralManagerOptionRestoreIdentifierKey)
       - it will not disable scanning when batterySaving mode is engaged (to keep the ibeacon functionality alive, we NEED scanning)
      This can also be set later on, using the setBackgroundScanning method.
     *
    **/
    public init(backgroundEnabled: Bool = true) {
        self.settings   = BluenetSettings()
        self.eventBus   = EventBus()
        self.bleManager = BleManager(eventBus: self.eventBus, backgroundEnabled: backgroundEnabled)
        
        // give the BLE manager a reference to the settings.
        self.bleManager.setSettings(settings)
        
        // pass on the shared objects to the worker classes
        self.dfu     = DfuHandler(     bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList)
        self.config  = ConfigHandler(  bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList)
        self.setup   = SetupHandler(   bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList)
        self.control = ControlHandler( bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList)
        self.power   = PowerHandler(   bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList)
        self.mesh    = MeshHandler(    bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList)
        self.device  = DeviceHandler(  bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList)
        self.state   = StateHandler(   bleManager:bleManager, eventBus: eventBus, settings: settings, deviceList: deviceList)
        
        _ = eventBus.on("disconnectCommandWritten", self._storeDisconnectCommandList)
        
        // subscribe to BLE advertisements (TODO: add encryption)
        _ = self.eventBus.on("advertisementData", self._parseAdvertisement)
    }
    
    open func enableBatterySaving() {
        self.bleManager.enableBatterySaving()
    }
    
    open func disableBatterySaving() {
        self.bleManager.disableBatterySaving()
    }
    
    open func setBackgroundScanning(newBackgroundState: Bool) {
        self.bleManager.setBackgroundScanning(newBackgroundState: newBackgroundState)
    }
    
    /**
     * Load a settings object into Bluenet
     */
    open func setSettings(encryptionEnabled: Bool, adminKey: String?, memberKey: String?, guestKey: String?, referenceId: String) {
        self.settings.loadKeys(
            encryptionEnabled: encryptionEnabled,
            adminKey: adminKey,
            memberKey: memberKey,
            guestKey: guestKey,
            referenceId: referenceId
        )
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
     * Start actively scanning for Crownstones (and guidestones) based on the scan response service uuid.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    open func startScanningForCrownstones() {
        self.startScanningForServices([
            CrownstoneBuiltinAdvertisementServiceUUID,
            CrownstonePlugAdvertisementServiceUUID,
            GuidestoneAdvertisementServiceUUID,
            DFUServiceUUID
        ])
    }
    
    
    /**
     * Start actively scanning for Crownstones (and guidestones) based on the scan response service uuid.
     * Scan results will be broadcasted on the "advertisementData" topic.
     *
     * This is the battery saving variant, only unique messages are shown.
     */
    open func startScanningForCrownstonesUniqueOnly() {
        self.startScanningForServicesUniqueOnly([
            CrownstoneBuiltinAdvertisementServiceUUID,
            CrownstonePlugAdvertisementServiceUUID,
            GuidestoneAdvertisementServiceUUID,
            DFUServiceUUID
        ])
    }
    
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    open func startScanningForService(_ serviceUUID: String) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForService(serviceUUID, uniqueOnly: false)
    }
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    open func startScanningForServices(_ serviceUUIDs: [String]) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForServices(serviceUUIDs, uniqueOnly: false)
    }
    
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic. 
     *
     * This is the battery saving variant, only unique messages are shown.
     */
    open func startScanningForServiceUniqueOnly(_ serviceUUID: String) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForService(serviceUUID, uniqueOnly: true)
    }
    
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic.
     *
     * This is the battery saving variant, only unique messages are shown.
     */
    open func startScanningForServicesUniqueOnly(_ serviceUUIDs: [String]) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForServices(serviceUUIDs, uniqueOnly: true)
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
        var delayTime : Double = 0
        if let timeOfLastDisconnectCommand = self.disconnectCommandTimeList[uuid] {
            let minimumTimeBetweenReconnects = timeoutDurations.reconnect // seconds
            let diff = Date().timeIntervalSince1970 - timeOfLastDisconnectCommand
            if (diff < minimumTimeBetweenReconnects) {
                delayTime = minimumTimeBetweenReconnects - diff
            }
        }
        
        let connectionCommand : voidPromiseCallback = {
            LOG.info("BLUENET_LIB: Connecting to \(uuid) now.")
            return self.bleManager.connect(uuid)
                .then{_ -> Promise<Void> in
                    LOG.info("BLUENET_LIB: connected!")
                    return Promise<Void> {fulfill, reject in
                        if (self.settings.isEncryptionEnabled()) {
                            self.control.getAndSetSessionNonce()
                                .then{_ -> Void in
                                    fulfill(())
                                }
                                .catch{err in reject(err)}
                        }
                        else {
                            fulfill(())
                        }
                    }
                };
        }
        
        if (delayTime != 0) {
            LOG.info("BLUENET_LIB: Delaying connection to \(uuid) with \(delayTime) seconds since it recently got a disconnectCommand.")
            return Promise<Void> {fulfill, reject in
                delay(delayTime, {
                    connectionCommand().then{ _ in fulfill(()) }.catch{err in reject(err) }
                })
            }
        }
        else {
            return connectionCommand()
        }
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
    open func getBleState() -> CBCentralManagerState {
        return self.bleManager.BleState
    }
    
    /**
     * Re-emit the state of the BLE controller.
     */
    open func emitBleState() {
        self.bleManager.emitBleState()
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
    
    open func waitToWrite() -> Promise<Void> {
        return self.bleManager.waitToWrite(0)
    }
    
    open func waitToWrite(_ iteration: UInt8 = 0) -> Promise<Void> {
        return self.bleManager.waitToWrite(iteration)
    }
    
    open func applicationWillEnterForeground() {
        self.bleManager.applicationWillEnterForeground()
    }
    
    open func applicationDidEnterBackground() {
        self.bleManager.applicationDidEnterBackground()
    }
    
    // MARK: util
    func _storeDisconnectCommandList(_ data: Any) {
        if let handleString = data as? String {
            self.disconnectCommandTimeList[handleString] = Date().timeIntervalSince1970
        }
    }
    
    func _parseAdvertisement(_ data: Any) {
        // first we check if the data is conforming to an advertisment
        if let castData = data as? Advertisement {
            // check if we already know this Crownstone
            if deviceList[castData.handle] != nil {
                deviceList[castData.handle]!.update(castData)
                if (deviceList[castData.handle]!.verified) {
                    // log debug for verified advertisement
                    self.counter += 1
                    LOG.debug("BLUENET_LIB: received verifiedAdvertisementData nr: \(self.counter)")
                    self.eventBus.emit("verifiedAdvertisementData",castData)
                    
                    // if we have a valid RSSI measurement:
                    if (castData.rssi.intValue < 0) {
                        
                        // handling setup packages
                        if (castData.isSetupPackage()) {
                            // log debug for nearest setup
                            LOG.debug("BLUENET_LIB: received SetupAdvertisement nr: \(self.counter)")
                            
                            
                            self.setupList[castData.handle] = NearestItem(name: castData.name, handle: castData.handle, rssi: castData.rssi.intValue, setupMode: true, verified: true)
                            // log debug for nearest setup
                            LOG.debug("BLUENET_LIB: received nearestSetupCrownstone nr: \(self.counter)")
                            
                            self._emitNearestSetupCrownstone()
                        }
                        else if (castData.isDFUPackage()) {
                            // log debug for nearest setup
                            LOG.debug("BLUENET_LIB: received DFUadvertisement nr: \(self.counter)")
                            
                            
                            self.dfuList[castData.handle] = NearestItem(name: castData.name, handle: castData.handle, rssi: castData.rssi.intValue, dfuMode: true, verified: true)
                            // log debug for nearest setup
                            LOG.debug("BLUENET_LIB: received nearestSetupCrownstone nr: \(self.counter)")
                            
                            self._emitNearestDFUCrownstone()

                        }
                        else {
                            // handling normal packages, we emit nearest Crownstone (since verifieds are also Crownstones) and verified nearest.
                            self._emitNearestCrownstone(topic: "nearestCrownstone", verifiedOnly: false);
                            self._emitNearestCrownstone(topic: "nearestVerifiedCrownstone", verifiedOnly: true);
                            self.setupList.removeValue(forKey: castData.handle)
                        }
                    }
                }
                else if (castData.isCrownstoneFamily) {
                    self.eventBus.emit("unverifiedAdvertisementData",castData)
                    // if the Crownstone is not verified yet, we can still emit a nearest Crownstone event if the RSSI is valid.
                    if (castData.rssi.intValue < 0) {
                        self._emitNearestCrownstone(topic: "nearestCrownstone", verifiedOnly: false);
                    }
                }
            }
            else {
                // add this Crownstone to the list that we keep track of.
                deviceList[castData.handle] = AvailableDevice(castData, { self.deviceList.removeValue(forKey: castData.handle)})
            }
        }
    }
    
    
    // TODO: can be optimized so it does not use a loop.
    // TODO: move this logic into a specific container class instead of the setupList dictionary
    func _emitNearestSetupCrownstone() {
        var nearestRSSI = -1000
        var nearestHandle = ""
        var nearestName = ""
        for (_ , nearestItem) in self.setupList {
            if (nearestItem.rssi > nearestRSSI) {
                nearestRSSI = nearestItem.rssi
                nearestHandle = nearestItem.handle
                nearestName = nearestItem.name
            }
        }
        if (nearestHandle != "" && nearestRSSI < 0) {
            let data = NearestItem(name: nearestName, handle: nearestHandle, rssi: nearestRSSI, setupMode: true, verified: true)
            self.eventBus.emit("nearestSetupCrownstone", data)
        }
    }
    
    // TODO: can be optimized so it does not use a loop.
    // TODO: move this logic into a specific container class instead of the setupList dictionary
    func _emitNearestDFUCrownstone() {
        var nearestRSSI = -1000
        var nearestHandle = ""
        var nearestName = ""
        for (_ , nearestItem) in self.dfuList {
            if (nearestItem.rssi > nearestRSSI) {
                nearestRSSI = nearestItem.rssi
                nearestHandle = nearestItem.handle
                nearestName = nearestItem.name
            }
        }
        if (nearestHandle != "" && nearestRSSI < 0) {
            let data = NearestItem(name: nearestName, handle: nearestHandle, rssi: nearestRSSI, dfuMode: true, verified: true)
            self.eventBus.emit("nearestDFUCrownstone", data)
        }
    }
    
    // TODO: can be optimized so it does not use a loop.
    // TODO: move this logic into a specific container class instead of the devicelist dictionary
    func _emitNearestCrownstone(topic: String, verifiedOnly: Bool = true) {
        var nearestRSSI = -1000
        var nearestHandle = ""
        var nearestName : String?
        var nearestVerified = false
        for (handle, device) in self.deviceList {
            if (device.rssi > nearestRSSI) {
                if ((verifiedOnly == true && device.verified == true) || verifiedOnly == false) {
                    nearestRSSI = device.rssi
                    nearestHandle = handle
                    nearestName = device.name
                    nearestVerified = device.verified
                }
            }
        }
        
        if (nearestName == nil) {
            nearestName = "nil"
        }
        
        if (nearestHandle != "" && nearestRSSI < 0) {
            let data = NearestItem(name: nearestName!, handle: nearestHandle, rssi: nearestRSSI, setupMode: false, verified: nearestVerified)
            self.eventBus.emit(topic, data)
        }
    }
    
    
}

