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
   |  "rawAdvertismentData"         |     Advertisement    |     When an advertisement packet is received
   |  "verifiedAdvertisementData"   |     Advertisement    |     When an advertisement has been decrypted successfully 3 consecutive times it is verified.
   |                                |                      |     Setup and DFU are also included since they dont need to be decrypted. This sorts out only your Crownstones.
   |  "nearestSetupCrownstone"      |     NearestItem      |     When a verified advertisement packet in setup mode is received, we check the list
   |                                |                      |     of available stones in setup mode and return the closest.
   |  "nearestCrownstone"           |     NearestItem      |     When a verified advertisement packet in setup mode is received, we check the list
   |                                |                      |     of available stones in setup mode and return the closest.
 */
open class Bluenet {
    // todo: set back to private, currently public for DEBUG
    var counter : UInt64 = 0
    open let bleManager : BleManager!
    open let blePeripheralManager : BlePeripheralManager!
    open var settings : BluenetSettings!
    let eventBus : EventBus!
    
    var reachableCrownstones = [String: AdvertismentValidator]()
    var setupList : CrownstoneContainer!
    var dfuList : CrownstoneContainer!
    var crownstoneList: CrownstoneContainer!
    var validatedCrownstoneList: CrownstoneContainer!
    
    var disconnectCommandTimeList = [String: Double]()
    
    var encryptionMap = [String: String]()

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
        self.bleManager = BleManager(eventBus: self.eventBus, settings: settings, backgroundEnabled: backgroundEnabled)
        self.blePeripheralManager = BlePeripheralManager(eventBus: self.eventBus, backgroundEnabled: backgroundEnabled);
        
        self.setupList               = CrownstoneContainer(setupMode: true,  dfuMode: false)
        self.dfuList                 = CrownstoneContainer(setupMode: false, dfuMode: true )
        self.crownstoneList          = CrownstoneContainer(setupMode: false, dfuMode: false)
        self.validatedCrownstoneList = CrownstoneContainer(setupMode: true,  dfuMode: true )
       
        // pass on the shared objects to the worker classes
        self.dfu     = DfuHandler(     bleManager:bleManager, eventBus: eventBus, settings: settings)
        self.config  = ConfigHandler(  bleManager:bleManager, eventBus: eventBus, settings: settings)
        self.setup   = SetupHandler(   bleManager:bleManager, eventBus: eventBus, settings: settings)
        self.control = ControlHandler( bleManager:bleManager, eventBus: eventBus, settings: settings)
        self.power   = PowerHandler(   bleManager:bleManager, eventBus: eventBus, settings: settings)
        self.mesh    = MeshHandler(    bleManager:bleManager, eventBus: eventBus, settings: settings)
        self.device  = DeviceHandler(  bleManager:bleManager, eventBus: eventBus, settings: settings)
        self.state   = StateHandler(   bleManager:bleManager, eventBus: eventBus, settings: settings)
        
        _ = eventBus.on("disconnectCommandWritten", self._storeDisconnectCommandList)
        
        // subscribe to BLE advertisements
//        _ = self.eventBus.on("advertisementData", self._parseAdvertisement)
        _ = self.eventBus.on("rawAdvertisementData", self._checkAdvertisement)
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
    
    open func startAdvertising(uuidString: String = "c005") {
        self.blePeripheralManager.startAdvertising(uuidString: uuidString)
    }
    
    open func startAdvertisingArray(uuidStrings: [String]) {
        self.blePeripheralManager.startAdvertisingArray(uuidStrings: uuidStrings)
    }
    
    open func stopAdvertising() {
        self.blePeripheralManager.stopAdvertising()
    }
    
    
    open func loadKeysets(encryptionEnabled: Bool, keySets: [KeySet]) {
        self.settings.loadKeySets(
            encryptionEnabled: encryptionEnabled,
            keySets: keySets
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
     * Returns if the BLE manager is initialized.
     * Should be used to make sure commands are not send before it's finished and get stuck.
     */
    open func isPeripheralReady() -> Promise<Void> {
        return self.blePeripheralManager.isReady()
    }

    
    /**
     * Connect to a BLE device with the provided handle.
     * This handle is unique per BLE device per iOS device and is NOT the MAC address.
     * Timeout is set to 3 seconds starting from the actual start of the connection.
     *   - It will abort other pending connection requests
     *   - It will disconnect from a connected device if that is the case
     */
    open func connect(_ handle: String, referenceId: String? = nil) -> Promise<Void> {
        var delayTime : Double = 0
        if let timeOfLastDisconnectCommand = self.disconnectCommandTimeList[handle] {
            let minimumTimeBetweenReconnects = timeoutDurations.reconnect // seconds
            let diff = Date().timeIntervalSince1970 - timeOfLastDisconnectCommand
            if (diff < minimumTimeBetweenReconnects) {
                delayTime = minimumTimeBetweenReconnects - diff
            }
        }
        
        let connectionCommand : voidPromiseCallback = {
            LOG.info("BLUENET_LIB: Connecting to \(handle) now.")
            return self.bleManager.connect(handle)
                .then{_ -> Promise<Void> in
                    LOG.info("BLUENET_LIB: connected!")
                    return Promise<Void> {fulfill, reject in
                        if (self.settings.isEncryptionEnabled()) {
                            // we have to validate if the referenceId is valid here, otherwise we cannot do encryption
                            if (referenceId == nil) {
                                return reject(BleError.INVALID_SESSION_REFERENCE_ID)
                            }
                            
                            if (self.settings.setSessionId(referenceId: referenceId!) == false) {
                                return reject(BleError.INVALID_SESSION_REFERENCE_ID)
                            }
                            
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
            LOG.info("BLUENET_LIB: Delaying connection to \(handle) with \(delayTime) seconds since it recently got a disconnectCommand.")
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
        
    }
    
    open func applicationDidEnterBackground() {
        
    }
    
    // MARK: util
    func _storeDisconnectCommandList(_ data: Any) {
        if let handleString = data as? String {
            self.disconnectCommandTimeList[handleString] = Date().timeIntervalSince1970
        }
    }
    


    func _checkAdvertisement(_ data: Any) {
        // first we check if the data is conforming to an advertisment
        if let castData = data as? Advertisement {
            // emit advertisementData
            self.eventBus.emit("advertisementData", castData)
            
            // check if this is a Crownstone, if not we don't need to do anything more. Raw scans can subscribe to the rawAdvertismentData topic.
            if (!castData.isCrownstoneFamily) { return }
            
            let handle = castData.handle
            
            // we will leave it up to the validator to determine what to do now.
            if self.reachableCrownstones[handle] == nil {
                self.reachableCrownstones[handle] = AdvertismentValidator(settings: self.settings)
            }
            
            let validator = self.reachableCrownstones[handle]!
            validator.update(advertisement: castData)
    
            
            if (validator.validated) {
                // emit verified advertisement
                self.eventBus.emit("verifiedAdvertisementData", castData)
                
                // emit nearestCrownstone
                self.addToList(adv: castData, crownstoneList: self.crownstoneList, topic: "nearestCrownstone", validated: true)
                
                switch validator.operationMode {
                    case CrownstoneMode.setup:
                        self.addToList(adv: castData, crownstoneList: self.setupList, topic: "nearestSetupCrownstone", validated: true)
                        self.dfuList.removeItem(handle: handle)
                        self.validatedCrownstoneList.removeItem(handle: handle)
                    case CrownstoneMode.dfu:
                        self.addToList(adv: castData, crownstoneList: self.dfuList, topic: "nearestDFUCrownstone", validated: true)
                        self.setupList.removeItem(handle: handle)
                        self.validatedCrownstoneList.removeItem(handle: handle)
                    case CrownstoneMode.operation:
                        self.addToList(adv: castData, crownstoneList: self.validatedCrownstoneList, topic: "nearestVerifiedCrownstone", validated: true)
                        self.dfuList.removeItem(handle: handle)
                        self.setupList.removeItem(handle: handle)
                    case CrownstoneMode.unknown:
                        // emit nearestCrownstone
                        break
                }
            }
            else {
                // emit unverifiedAdvertisementData
                self.eventBus.emit("unverifiedAdvertisementData", castData)
                
                // emit nearestCrownstone
                self.addToList(adv: castData, crownstoneList: self.crownstoneList, topic: "nearestCrownstone", validated: false)
            }
        }
    }
    
    func addToList(adv: Advertisement, crownstoneList: CrownstoneContainer, topic: String, validated: Bool) {
        crownstoneList.load(name: adv.name, handle: adv.handle, rssi: adv.rssi.intValue, validated: validated)
        let nearestItem = crownstoneList.getNearestItem()
        if (nearestItem != nil) {
            self.eventBus.emit(topic, nearestItem!)
        }
    }
    
}

