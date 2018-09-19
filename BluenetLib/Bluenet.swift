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
public typealias processCallback = (Any) -> ProcessType
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
public class Bluenet {
    // todo: set back to private, currently public for DEBUG
    var counter : UInt64 = 0
    public let bleManager : BleManager!
    public let blePeripheralManager : BlePeripheralManager!
    public var settings : BluenetSettings!
    let eventBus : EventBus!
    var deviceList = [String: AvailableDevice]()
    var setupList : NearestItemContainer!
    var dfuList : NearestItemContainer!
    var disconnectCommandTimeList = [String: Double]()

    // declare the classes handling the library protocol
    public let dfu      : DfuHandler!
    public let config   : ConfigHandler!
    public let setup    : SetupHandler!
    public let control  : ControlHandler!
    public let power    : PowerHandler!
    public let mesh     : MeshHandler!
    public let device   : DeviceHandler!
    public let state    : StateHandler!

    
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
        self.blePeripheralManager = BlePeripheralManager(eventBus: self.eventBus, backgroundEnabled: backgroundEnabled);
        
        self.setupList = NearestItemContainer()
        self.dfuList   = NearestItemContainer()
        
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
        
        // subscribe to BLE advertisements
        _ = self.eventBus.on("advertisementData", self._parseAdvertisement)
    }
    
    public func enableBatterySaving() {
        self.bleManager.enableBatterySaving()
    }
    
    public func disableBatterySaving() {
        self.bleManager.disableBatterySaving()
    }
    
    public func setBackgroundScanning(newBackgroundState: Bool) {
        self.bleManager.setBackgroundScanning(newBackgroundState: newBackgroundState)
    }
    
    public func startAdvertising(uuidString: String = "c005") {
        self.blePeripheralManager.startAdvertising(uuidString: uuidString)
    }
    
    public func startAdvertisingArray(uuidStrings: [String]) {
        self.blePeripheralManager.startAdvertisingArray(uuidStrings: uuidStrings)
    }
    
    public func stopAdvertising() {
        self.blePeripheralManager.stopAdvertising()
    }
    
    /**
     * Load a settings object into Bluenet
     */
    public func setSettings(encryptionEnabled: Bool, adminKey: String?, memberKey: String?, guestKey: String?, referenceId: String) {
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
    public func startScanning() {
        self.bleManager.stopScanning()
        self.bleManager.startScanning()
    }
    
    
    /**
     * Start actively scanning for Crownstones (and guidestones) based on the scan response service uuid.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    public func startScanningForCrownstones() {
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
    public func startScanningForCrownstonesUniqueOnly() {
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
    public func startScanningForService(_ serviceUUID: String) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForService(serviceUUID, uniqueOnly: false)
    }
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic.
     */
    public func startScanningForServices(_ serviceUUIDs: [String]) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForServices(serviceUUIDs, uniqueOnly: false)
    }
    
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic. 
     *
     * This is the battery saving variant, only unique messages are shown.
     */
    public func startScanningForServiceUniqueOnly(_ serviceUUID: String) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForService(serviceUUID, uniqueOnly: true)
    }
    
    
    /**
     * Start actively scanning for BLE devices containing a specific serviceUUID.
     * Scan results will be broadcasted on the "advertisementData" topic.
     *
     * This is the battery saving variant, only unique messages are shown.
     */
    public func startScanningForServicesUniqueOnly(_ serviceUUIDs: [String]) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForServices(serviceUUIDs, uniqueOnly: true)
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
     * Returns if the BLE manager is initialized.
     * Should be used to make sure commands are not send before it's finished and get stuck.
     */
    public func isPeripheralReady() -> Promise<Void> {
        return self.blePeripheralManager.isReady()
    }

    
    /**
     * Connect to a BLE device with the provided UUID.
     * This UUID is unique per BLE device per iOS device and is NOT the MAC address.
     * Timeout is set to 3 seconds starting from the actual start of the connection.
     *   - It will abort other pending connection requests
     *   - It will disconnect from a connected device if that is the case
     */
    public func connect(_ uuid: String) -> Promise<Void> {
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
    public func disconnect() -> Promise<Void> {
        return self.bleManager.disconnect()
    }
    
    
    /**
     * Get the state of the BLE controller.
     */
    public func getBleState() -> CBCentralManagerState {
        return self.bleManager.BleState
    }
    
    /**
     * Re-emit the state of the BLE controller.
     */
    public func emitBleState() {
        self.bleManager.emitBleState()
    }
    
    
    /**
     * Subscribe to a topic with a callback. This method returns an Int which is used as identifier of the subscription.
     * This identifier is supplied to the off method to unsubscribe.
     */
    public func on(_ topic: String, _ callback: @escaping eventCallback) -> voidCallback {
        return self.eventBus.on(topic, callback)
    }
    
    
    public func waitToReconnect() -> Promise<Void> {
        return self.bleManager.waitToReconnect()
    }
    
    public func waitToWrite() -> Promise<Void> {
        return self.bleManager.waitToWrite(0)
    }
    
    public func waitToWrite(_ iteration: UInt8 = 0) -> Promise<Void> {
        return self.bleManager.waitToWrite(iteration)
    }
    
    public func applicationWillEnterForeground() {
        self.bleManager.applicationWillEnterForeground()
    }
    
    public func applicationDidEnterBackground() {
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
                            
                            // remove the item from the dfuList if this is in there. In the event a state changes, we don't want to keep it in the old lists
                            self.dfuList.removeItem(handle: castData.handle)
                            
                            // add entry to the dfu list
                            self.setupList.load(name: castData.name, handle: castData.handle, rssi: castData.rssi.intValue)
                            let nearestSetup = self.setupList.getNearestItem(setupMode: true, dfuMode: false)
                            if nearestSetup != nil {
                                self.eventBus.emit("nearestSetupCrownstone", nearestSetup!)
                            }
                            
                             // log debug for nearest setup
                            LOG.debug("BLUENET_LIB: received nearestSetupCrownstone nr: \(self.counter)")
   
                        }
                        else if (castData.isDFUPackage()) {
                            // log debug for nearest setup
                            LOG.debug("BLUENET_LIB: received DFUadvertisement nr: \(self.counter)")
                            
                            // remove the item from the setuplist if this is in there. In the event a state changes, we don't want to keep it in the old lists
                            self.setupList.removeItem(handle: castData.handle)
                            
                            // add entry to the dfu list
                            self.dfuList.load(name: castData.name, handle: castData.handle, rssi: castData.rssi.intValue)
                            let nearestDFU = self.dfuList.getNearestItem(setupMode: false, dfuMode: true)
                            if nearestDFU != nil {
                                self.eventBus.emit("nearestDFUCrownstone", nearestDFU!)
                            }
                            
                            // log debug for nearest setup
                            LOG.debug("BLUENET_LIB: received nearestSetupCrownstone nr: \(self.counter)")
                        }
                        else {
                            // handling normal packages, we emit nearest Crownstone (since verifieds are also Crownstones) and verified nearest.
                            self._emitNearestCrownstone(topic: "nearestCrownstone", verifiedOnly: false);
                            self._emitNearestCrownstone(topic: "nearestVerifiedCrownstone", verifiedOnly: true);
                            self.dfuList.removeItem(handle: castData.handle)
                            self.setupList.removeItem(handle: castData.handle)
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

