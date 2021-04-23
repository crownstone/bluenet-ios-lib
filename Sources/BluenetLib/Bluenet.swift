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
 
 Advertising API:
 
 startAdvertising() --> used for the phone to start advertising. This will start the ticks. If this is not called, broadcast commands can still be sent.
 
 stopAdvertising() --> stop advertising the base payloads and fail all active elements. Completely Stop Broadcasting. 
 
 cancelAllActiveBroadcasts() --> fail all commands that are broadcasting. Will revert to the base advertisements
 
 startAdvertisingArray(uuids: [UInt16]) --> direct control ol broadcast payload. Does not use the bluenet broadcasting at all. Used by watch.
 
 startAdvertisingArray(uuids: [CBUUID]) --> direct control ol broadcast payload. Does not use the bluenet broadcasting at all. Used by watch.
 
 isPeripheralReady() --> check if ready to advertise
 
 
 
 */
public class Bluenet {
    // todo: set back to private, currently public for DEBUG
    var counter : UInt64 = 0
    public let bleManager : BleManager!
    let peripheralStateManager : PeripheralStateManager!
    public var settings : BluenetSettings!
    let eventBus : EventBus!
    
    var reachableCrownstones = [String: AdvertismentValidator]()
    var setupList : CrownstoneContainer!
    var dfuList   : CrownstoneContainer!
    var crownstoneList: CrownstoneContainer!
    var validatedCrownstoneList: CrownstoneContainer!
    
    var disconnectCommandTimeList = [String: Double]()
    
    var encryptionMap = [String: String]()

    public let broadcast  : BroadcastHandler!
    
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
        self.peripheralStateManager = PeripheralStateManager(eventBus: self.eventBus, settings: settings, backgroundEnabled: backgroundEnabled)
        self.bleManager = BleManager(peripheralStateManager: self.peripheralStateManager, eventBus: self.eventBus, settings: settings, backgroundEnabled: backgroundEnabled)
        
        
        self.setupList               = CrownstoneContainer()
        self.dfuList                 = CrownstoneContainer()
        self.crownstoneList          = CrownstoneContainer()
        self.validatedCrownstoneList = CrownstoneContainer()
        
        self.broadcast = BroadcastHandler(peripheralStateManager: self.peripheralStateManager, eventBus: eventBus, settings: settings)
        
        _ = eventBus.on("disconnectCommandWritten", self._storeDisconnectCommandList)
        
        // subscribe to BLE advertisements
//        _ = self.eventBus.on("advertisementData", self._parseAdvertisement)
        _ = self.eventBus.on("rawAdvertisementData", self._checkAdvertisement)
    }
    
    public func config(_ handle: UUID) -> ConfigHandler {
        return ConfigHandler(handle: handle, bleManager:bleManager, eventBus: eventBus, settings: settings)
    }
    
    public func control(_ handle: UUID) -> ControlHandler {
        return ControlHandler(handle: handle, bleManager:bleManager, eventBus: eventBus, settings: settings)
    }
    
    public func setup(_ handle: UUID) -> SetupHandler {
        return SetupHandler(handle: handle, bleManager:bleManager, eventBus: eventBus, settings: settings)
    }
    
    public func debug(_ handle: UUID) -> DebugHandler {
        return DebugHandler(handle: handle, bleManager:bleManager, eventBus: eventBus, settings: settings)
    }
    
    public func mesh(_ handle: UUID) -> MeshHandler {
        return MeshHandler(handle: handle, bleManager:bleManager, eventBus: eventBus, settings: settings)
    }
    
    public func device(_ handle: UUID) -> DeviceHandler {
        return DeviceHandler(handle: handle, bleManager:bleManager, eventBus: eventBus, settings: settings)
    }
    
    public func state(_ handle: UUID) -> StateHandler {
        return StateHandler(handle: handle, bleManager:bleManager, eventBus: eventBus, settings: settings)
    }
    
    #if os(iOS)
    public func dfu(_ handle: UUID) -> DfuHandler {
        return DfuHandler(handle: handle, bleManager:bleManager, eventBus: eventBus, settings: settings)
    }
    #endif
    
    public func hub(_ handle: UUID) -> HubHandler {
        return HubHandler(handle: handle, bleManager:bleManager, eventBus: eventBus, settings: settings)
    }
    
    public func behaviour(_ handle: UUID) -> BehaviourHandler {
        return BehaviourHandler(handle: handle, bleManager:bleManager, eventBus: eventBus, settings: settings)
    }
    
   #if os(iOS)
    public func checkBroadcastAuthorization() -> String {
        return self.peripheralStateManager.checkBroadcastAuthorization()
    }
    
    public func startPeripheral() {
        self.peripheralStateManager.startPeripheral()
    }
    #endif
    
    
    public func setSunTimes(sunriseSecondsSinceMidnight: UInt32, sunsetSecondsSinceMidnight: UInt32) {
        self.settings.setSunTimes(sunriseSecondsSinceMidnight: sunriseSecondsSinceMidnight, sunsetSecondsSinceMidnight: sunsetSecondsSinceMidnight)
        self.peripheralStateManager.updateAdvertisements()
    }
    
    public func enableBatterySaving() {
        self.bleManager.enableBatterySaving()
    }
    
    public func disableBatterySaving() {
        self.bleManager.disableBatterySaving()
    }
    
    public func setBackgroundOperations(newBackgroundState: Bool) {
        self.bleManager.setBackgroundOperations(newBackgroundState: newBackgroundState)
        self.peripheralStateManager.setBackgroundOperations(newBackgroundState: newBackgroundState)
    }
    
    public func setLocationState(sphereUID: UInt8, locationId: UInt8, profileIndex: UInt8, deviceToken: UInt8, referenceId: String) {
        self.settings.setLocationState(sphereUID: sphereUID, locationId: locationId, profileIndex: profileIndex, deviceToken: deviceToken, referenceId: referenceId)
        self.eventBus.emit("newLocationState", true)
    }
    
    public func setDevicePreferences(rssiOffset: Int8, tapToToggle: Bool, ignoreForBehaviour: Bool, useBackgroundBroadcasts: Bool, useBaseBroadcasts: Bool, useTimeBasedNonce: Bool, trackingNumber: UInt32 = 0) {
        self.settings.setDevicePreferences(rssiOffset: rssiOffset, tapToToggle: tapToToggle, ignoreForBehaviour: ignoreForBehaviour, useBackgroundBroadcasts: useBackgroundBroadcasts, useBaseBroadcasts: useBaseBroadcasts, useTimeBasedNonce:useTimeBasedNonce, trackingNumber: trackingNumber)
        self.eventBus.emit("newDevicePreferences", true)
    }
    
    public func setKnownValidatedHandle(handle: String, referenceId: String) {
        if let candidate = self.reachableCrownstones[handle] {
            candidate.validate(referenceId: referenceId)
        }
        else {
            self.reachableCrownstones[handle] = AdvertismentValidator(settings: self.settings)
            self.reachableCrownstones[handle]!.validate(referenceId: referenceId)
        }
    }
    
    
    public func loadKeysets(encryptionEnabled: Bool, keySets: [KeySet]) {
        self.settings.loadKeySets(
            encryptionEnabled: encryptionEnabled,
            keySets: keySets
        )
        self.eventBus.emit("newKeysets", true)
        
        for (_, validator) in self.reachableCrownstones {
            validator.releaseLockOnDecryption()
        }
    }
    
    #if os(iOS)
    public func startAdvertising() {
        self.peripheralStateManager.startAdvertising()
    }
    
    public func stopAdvertising() {
        self.peripheralStateManager.stopAdvertising()
    }
    #endif
    
    public func cancelAllActiveBroadcasts() {
        self.peripheralStateManager.stopActiveBroadcasts()
    }
    
    public func startAdvertisingArray(uuids: [UInt16]) {
        self.peripheralStateManager.advertiseArray(uuids: uuids)
    }
    
    public func startAdvertisingArray(uuids: [CBUUID]) {
        self.peripheralStateManager.advertiseArray(uuids: uuids)
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
            DFUServiceUUID,
            DFUSecureServiceUUID
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
            DFUServiceUUID,
            DFUSecureServiceUUID
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
    public func startScanningForServices(_ serviceUUIDs: [CBUUID]) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForServicesCBUUID(serviceUUIDs, uniqueOnly: false)
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
    public func startScanningForServicesUniqueOnly(_ serviceUUIDs: [CBUUID]) {
        self.bleManager.stopScanning()
        self.bleManager.startScanningForServicesCBUUID(serviceUUIDs, uniqueOnly: true)
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
        return self.peripheralStateManager.blePeripheralManager.isReady()
    }

    
    /**
     * Connect to a BLE device with the provided handle.
     * This handle is unique per BLE device per iOS device and is NOT the MAC address.
     * Timeout is set to 3 seconds starting from the actual start of the connection.
     *   - It will abort other pending connection requests
     *   - It will disconnect from a connected device if that is the case
     */
    public func connect(_ handle: String, referenceId: String? = nil) -> Promise<CrownstoneMode> {
        let uid = UUID(uuidString: handle)
        guard uid != nil else { return Promise<CrownstoneMode> { seal in seal.reject(BluenetError.INVALID_UUID) }}
        
        let handleUUID = uid!
        guard self.bleManager.isConnected(handleUUID) == false else {
            LOG.info("BLUENET_LIB: Already connected to this handle \(handle).")
            return Promise<CrownstoneMode> { seal in seal.fulfill(self.bleManager.connectionState(handleUUID).operationMode) }
        }
        LOG.info("BLUENET_LIB: Connecting to \(handle) now.")
       
        self.bleManager.connectionState(handleUUID).start(settings: self.settings)
        
        
        return self.bleManager.connect(handle)
            .then{_ -> Promise<ModeInformation> in
                LOG.info("BLUENET_LIB: connected! \(handle).")
                return _getCrownstoneModeInformation(bleManager: self.bleManager, handle: handleUUID)
            }
            .then{ modeInfo -> Promise<CrownstoneMode> in
                LOG.info("BLUENET_LIB: got mode info! \(modeInfo)  \(handle).")
                self.bleManager.connectionState(handleUUID).setConnectionProtocolVersion(modeInfo.controlMode)
                self.bleManager.connectionState(handleUUID).setOperationMode(modeInfo.operationMode)

                if modeInfo.operationMode == .setup {
                    // setup mode, handle the setup encryption.
                    return Promise<CrownstoneMode> {seal in
                        self.setup(handleUUID).handleSetupPhaseEncryption()
                            .done{ _   in seal.fulfill(.setup) }
                            .catch{err in seal.reject(err)     }
                    }
                }
                else {
                    return Promise<CrownstoneMode> {seal in
                        // operation mode (or dfu mode), setup the session nonce.
                        if modeInfo.operationMode == .operation {
                            if (self.bleManager.connectionState(handleUUID).isEncryptionEnabled()) {
                                // we have to validate if the referenceId is valid here, otherwise we cannot do encryption
                                var activeReferenceId = referenceId
                                
                                if (referenceId == nil) {
                                    activeReferenceId = self.getReferenceId(handle: handle)
                                    if (activeReferenceId == nil) {
                                        return seal.reject(BluenetError.INVALID_SESSION_REFERENCE_ID)
                                    }
                                }
                                
                                if (self.settings.keysAvailable(referenceId: activeReferenceId!) == false) {
                                    return seal.reject(BluenetError.INVALID_SESSION_REFERENCE_ID)
                                }
                                
                                // load the required encryption keys into the connectionstate.
                                self.bleManager.connectionState(handleUUID).setActiveKeySet(self.settings.keySets[activeReferenceId!]!)
                                self.control(handleUUID).getAndSetSessionNonce()
                                    .done{_ -> Void in
                                        seal.fulfill(modeInfo.operationMode)
                                    }
                                    .catch{err in seal.reject(err)}
                            }
                            else {
                                seal.fulfill(modeInfo.operationMode)
                            }
                        }
                        else {
                            seal.fulfill(modeInfo.operationMode)
                        }
                    }
                }
            }
    }

    
    public func cancelConnectionRequest(_ handle: String) -> Promise<Void> {
        let handleUUID = UUID(uuidString: handle)
        
        return self.bleManager.abortConnecting(handleUUID!)
    }
    
    /**
     * Disconnect from the connected device. Will also fulfil if there is nothing connected.
     * Timeout is set to 2 seconds.
     */
    public func disconnect(handle: String) -> Promise<Void> {
        let uid = UUID(uuidString: handle)
        if let handleUUID = uid {
            return self.bleManager.disconnect(handleUUID)
        }
        else {
            return Promise<Void> { seal in seal.reject(BluenetError.INVALID_UUID) }
        }
    }
    
    
    /**
     * Get the state of the BLE controller.
     */
    public func getBleState() -> CBManagerState {
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
    
    public func wait(_ seconds: Double) -> Promise<Void> {
        return self.bleManager.wait(seconds: seconds)
    }
    
    public func waitToWrite() -> Promise<Void> {
        return self.bleManager.waitToWrite(0)
    }
    
    public func waitToWrite(_ iteration: UInt8 = 0) -> Promise<Void> {
        return self.bleManager.waitToWrite(iteration)
    }
    
    public func applicationWillEnterForeground() {
        self.settings.backgroundState = false
        self.peripheralStateManager.applicationWillEnterForeground()
    }
    
    public func applicationDidEnterBackground() {
        self.settings.backgroundState = true
        self.peripheralStateManager.applicationDidEnterBackground()
    }
    
    public func getReferenceId(handle: String) -> String? {
        if let validator = self.reachableCrownstones[handle] {
            return validator.validatedReferenceId
        }
        return nil
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
            // check if this is a Crownstone, if not we don't need to do anything more. Raw scans can subscribe to the advertisementData topic.
            if (!castData.isCrownstoneFamily && castData.operationMode != .dfu) { return }
            
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
                
                
                switch validator.operationMode {
                    case CrownstoneMode.setup:
                        self.addToList(adv: castData, crownstoneList: self.crownstoneList, topic: "nearestCrownstone",      validated: true, setupMode: true, dfuMode: false)
                        self.addToList(adv: castData, crownstoneList: self.setupList,      topic: "nearestSetupCrownstone", validated: true, setupMode: true, dfuMode: false)
                        self.dfuList.removeItem(handle: handle)
                        self.validatedCrownstoneList.removeItem(handle: handle)
                    case CrownstoneMode.dfu:
                        self.addToList(adv: castData, crownstoneList: self.crownstoneList, topic: "nearestCrownstone",    validated: true, setupMode: false, dfuMode: true)
                        self.addToList(adv: castData, crownstoneList: self.dfuList,        topic: "nearestDFUCrownstone", validated: true, setupMode: false, dfuMode: true)
                        self.setupList.removeItem(handle: handle)
                        self.validatedCrownstoneList.removeItem(handle: handle)
                    case CrownstoneMode.operation:
                        self.addToList(adv: castData, crownstoneList: self.crownstoneList,          topic: "nearestCrownstone",         validated: true, setupMode: false, dfuMode: false)
                        self.addToList(adv: castData, crownstoneList: self.validatedCrownstoneList, topic: "nearestVerifiedCrownstone", validated: true, setupMode: false, dfuMode: false)
                        self.dfuList.removeItem(handle: handle)
                        self.setupList.removeItem(handle: handle)
                    case CrownstoneMode.unknown:
                        // emit nearestCrownstone
                        self.addToList(adv: castData, crownstoneList: self.crownstoneList, topic: "nearestCrownstone", validated: true, setupMode: false, dfuMode: false)
                        
                        break
                }
            }
            else {
                if (!castData.isCrownstoneFamily) { return }
                
                // emit unverifiedAdvertisementData
                self.eventBus.emit("unverifiedAdvertisementData", castData)
                
                // emit nearestCrownstone
                self.addToList(adv: castData, crownstoneList: self.crownstoneList, topic: "nearestCrownstone", validated: false, setupMode: false, dfuMode: false)
            }
            
            // finally, we emit advertisementData. This has to be done at the end of this function to ensure this is also decrypted if that was possible.
            self.eventBus.emit("advertisementData", castData)
        }
    }
    
    func addToList(adv: Advertisement, crownstoneList: CrownstoneContainer, topic: String, validated: Bool, setupMode: Bool, dfuMode: Bool) {
        crownstoneList.load(name: adv.name, handle: adv.handle, rssi: adv.rssi.intValue, validated: validated, setupMode: setupMode, dfuMode: dfuMode)
        let nearestItem = crownstoneList.getNearestItem()
        if (nearestItem != nil) {
            self.eventBus.emit(topic, nearestItem!)
        }
    }
    
}

