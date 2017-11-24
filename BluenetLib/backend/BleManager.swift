//
//  bleMangager.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 11/04/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth
import SwiftyJSON
import PromiseKit

public enum BleError : Error {
    case DISCONNECTED
    case CONNECTION_CANCELLED
    case CONNECTION_FAILED
    case NOT_CONNECTED
    case NO_SERVICES
    case NO_CHARACTERISTICS
    case SERVICE_DOES_NOT_EXIST
    case CHARACTERISTIC_DOES_NOT_EXIST
    case WRONG_TYPE_OF_PROMISE
    case INVALID_UUID
    case NOT_INITIALIZED
    case CANNOT_SET_TIMEOUT_WITH_THIS_TYPE_OF_PROMISE
    case TIMEOUT
    case DISCONNECT_TIMEOUT
    case CANCEL_PENDING_CONNECTION_TIMEOUT
    case CONNECT_TIMEOUT
    case GET_SERVICES_TIMEOUT
    case GET_CHARACTERISTICS_TIMEOUT
    case READ_CHARACTERISTIC_TIMEOUT
    case WRITE_CHARACTERISTIC_TIMEOUT
    case ENABLE_NOTIFICATIONS_TIMEOUT
    case DISABLE_NOTIFICATIONS_TIMEOUT
    case CANNOT_WRITE_AND_VERIFY
    case CAN_NOT_CONNECT_TO_UUID
    case COULD_NOT_FACTORY_RESET
    case INCORRECT_RESPONSE_LENGTH
    case UNKNOWN_TYPE
    
    // encryption errors
    case INVALID_SESSION_DATA
    case NO_SESSION_NONCE_SET
    case COULD_NOT_VALIDATE_SESSION_NONCE
    case INVALID_SIZE_FOR_ENCRYPTED_PAYLOAD
    case INVALID_SIZE_FOR_SESSION_NONCE_PACKET
    case INVALID_PACKAGE_FOR_ENCRYPTION_TOO_SHORT
    case INVALID_KEY_FOR_ENCRYPTION
    case DO_NOT_HAVE_ENCRYPTION_KEY
    case COULD_NOT_ENCRYPT
    case COULD_NOT_ENCRYPT_KEYS_NOT_SET
    case COULD_NOT_DECRYPT_KEYS_NOT_SET
    case COULD_NOT_DECRYPT
    case CAN_NOT_GET_PAYLOAD
    case USERLEVEL_IN_READ_PACKET_INVALID
    case READ_SESSION_NONCE_ZERO_MAYBE_ENCRYPTION_DISABLED
    
    // recovery error
    case NOT_IN_RECOVERY_MODE
    case CANNOT_READ_FACTORY_RESET_CHARACTERISTIC
    case RECOVER_MODE_DISABLED
    
    // input errors
    case INVALID_TX_POWER_VALUE
    
    // mesh
    case NO_KEEPALIVE_STATE_ITEMS
    case NO_SWITCH_STATE_ITEMS
    
    // DFU
    case DFU_OVERRULED
    case DFU_ABORTED
    case DFU_ERROR
    case COULD_NOT_FIND_PERIPHERAL
    case PACKETS_DO_NOT_MATCH
    case NOT_IN_DFU_MODE
    
    // promise errors
    case REPLACED_WITH_OTHER_PROMISE
    
    // timer errors
    case INCORRECT_SCHEDULE_ENTRY_INDEX
    case INCORRECT_DATA_COUNT_FOR_ALL_TIMERS
    case NO_SCHEDULE_ENTRIES_AVAILABLE
    case NO_TIMER_FOUND
}

struct timeoutDurations {
    static let disconnect              : Double = 3
    static let cancelPendingConnection : Double = 3
    static let connect                 : Double = 10
    static let reconnect               : Double = 0.5
    static let getServices             : Double = 3
    static let getCharacteristics      : Double = 3
    static let readCharacteristic      : Double = 3
    static let writeCharacteristic     : Double = 4
    static let writeCharacteristicWithout : Double = 0.5
    static let enableNotifications     : Double = 2
    static let disableNotifications    : Double = 2
    static let waitForBond             : Double = 12
    static let waitForWrite            : Double = 0.6
    static let waitForReconnect        : Double = 2.0
    static let waitForRestart          : Double = 2
    static let waitForMeshPropagation  : Double = 0.5
}



open class BleManager: NSObject, CBPeripheralDelegate {
    open var centralManager : CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    var connectingPeripheral: CBPeripheral?
    
    var BleState : CBCentralManagerState = .unknown
    var pendingPromise : promiseContainer!
    var eventBus : EventBus!
    var notificationEventBus : EventBus!
    open var settings : BluenetSettings!
    
    var decoupledDelegate = false
    
    var uniquenessReference = [String: String]()
    var scanUniqueOnly = false
    var scanning = false
    var scanningStateStored = false
    var scanningForServices : [CBUUID]? = nil
    
    var batterySaving = false
    var backgroundEnabled = true
    
    var cBmanagerUpdatedState = false
    
    var CBDelegate : BluenetCBDelegate!
    var CBDelegateBackground : BluenetCBDelegateBackground!

    public init(eventBus: EventBus, backgroundEnabled: Bool = true) {
        super.init();
        
        self.notificationEventBus = EventBus()
        self.settings = BluenetSettings()
        self.eventBus = eventBus
        
        self.backgroundEnabled = backgroundEnabled
        
        self.CBDelegate = BluenetCBDelegate(bleManager: self)
        self.CBDelegateBackground = BluenetCBDelegateBackground(bleManager: self)
        self.setCentralManager()
        
        
        // initialize the pending promise containers
        self.pendingPromise = promiseContainer()
    }
    
    open func applicationWillEnterForeground() {
        
    }
    
    open func applicationDidEnterBackground() {
        
    }
    
    open func setBackgroundScanning(newBackgroundState: Bool) {
        if (self.backgroundEnabled == newBackgroundState) {
            return
        }
        centralManager.stopScan()
        self.backgroundEnabled = newBackgroundState
        self.BleState = .unknown
        self.cBmanagerUpdatedState = false
        self.setCentralManager()
        
        self.isReady().then{ _ in self.restoreScanning()}.catch{ err in print(err) }
        
        // fallback.
        delay(3, { 
            if (self.cBmanagerUpdatedState == false) {
                self.BleState = .poweredOn
            }
        })
    }
    
    func setCentralManager() {
        if (self.backgroundEnabled) {
            /**
             * The system uses this UID to identify a specific central manager.
             * As a result, the UID must remain the same for subsequent executions of the app
             * in order for the central manager to be successfully restored.
             **/
            self.centralManager = CBCentralManager(
                delegate: self.CBDelegateBackground,
                queue: nil,
                options: [CBCentralManagerOptionShowPowerAlertKey: true, CBCentralManagerOptionRestoreIdentifierKey: APPNAME +  "BluenetIOS"]
            )
        }
        else {
            self.centralManager = CBCentralManager(
                delegate: self.CBDelegate,
                queue: nil,
                options: [CBCentralManagerOptionShowPowerAlertKey: true]
            )
        }
    }
    
    /**
     *
     * Battery saving means that initially, the lib will ignore any ble advertisements. No events originating from BLE advertisements 
     * will be propagated and nothing will be decrypted.
     *
     * Additionally, if background mode is disabled, it will also disable scanning alltogether. This will cause the app to fall asleep.
     * This can be disabled by passing the optional doNotChangeScanning parameter.
     *
    **/
    open func enableBatterySaving(doNotChangeScanning: Bool = false) {
        LOG.info("BLUENET_LIB: Enabled Battery Saving. doNotChangeScanning: \(doNotChangeScanning)")
        self.batterySaving = true
        
        if (doNotChangeScanning == false) {
            if (self.backgroundEnabled == false) {
                if (self.decoupledDelegate == true) {
                    LOG.info("BLUENET_LIB: ignored enableBatterySaving scan pausing because the delegate is decoupled (likely due to DFU in progress)")
                    return
                }
                self.pauseScanning()
            }
        }
    }
    
    /**
     * Similar to enable, this will revert the changes done by enable.
     **/
    open func disableBatterySaving(doNotChangeScanning : Bool = false) {
        LOG.info("BLUENET_LIB: Disabled Battery Saving. doNotChangeScanning: \(doNotChangeScanning)")
        self.batterySaving = false
        if (doNotChangeScanning == false) {
            if (self.backgroundEnabled == false) {
                if (self.decoupledDelegate == true) {
                    LOG.info("BLUENET_LIB: ignored disableBatterySaving scan restoration because the delegate is decoupled (likely due to DFU in progress)")
                    return
                }
                self.restoreScanning()
            }
        }
    }
    
    open func setSettings(_ settings: BluenetSettings) {
        self.settings = settings
    }
    
    open func decoupleFromDelegate() {
        LOG.info("Decoupling from Delegate")
        self.decoupledDelegate = true
    }
    
    open func reassignDelegate() {
        LOG.info("Reassigning Delegate")
        self.decoupledDelegate = false
        if (self.backgroundEnabled) {
            self.centralManager.delegate = self.CBDelegateBackground
        }
        else {
            self.centralManager.delegate = self.CBDelegate
        }
        self.restoreScanning()
    }
   
    open func emitBleState() {
        if (self.backgroundEnabled) {
            self.CBDelegateBackground.centralManagerDidUpdateState(self.centralManager)
        }
        else {
            self.CBDelegate.centralManagerDidUpdateState(self.centralManager)
        }
    }
    
    // MARK: API
    
    /**
     * This method will fulfill when the bleManager is ready. It polls itself every 0.25 seconds. Never rejects.
     */
    open func isReady() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            if (self.BleState != .poweredOn) {
                delay(0.50, { _ = self.isReady().then{_ -> Void in fulfill(())} })
            }
            else {
                fulfill(())
            }
        }
    }
    
    open func waitToReconnect() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in delay(timeoutDurations.waitForReconnect, fulfill) }
    }
    
    open func waitForRestart() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in delay(timeoutDurations.waitForRestart, fulfill) }
    }
    
    // this delay is set up for calls that need to write to storage.
    open func waitToWrite(_ iteration: UInt8 = 0) -> Promise<Void> {
        if (iteration > 0) {
            LOG.info("BLUENET_LIB: Could not verify immediatly, waiting longer between steps...")
            return Promise<Void> { fulfill, reject in delay(2 * timeoutDurations.waitForWrite, fulfill) }
        }
        
        return Promise<Void> { fulfill, reject in delay(timeoutDurations.waitForWrite, fulfill) }
    }

    
    open func getPeripheral(_ uuid: String) -> CBPeripheral? {
        let nsUuid = UUID(uuidString: uuid)
        if (nsUuid == nil) {
            return nil
        }

        // get a peripheral from the known list (TODO: check what happens if it requests an unknown one)
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [nsUuid!]);
        if (peripherals.count == 0) {
            return nil
        }
        
        return peripherals[0]
    }
    
    /**
     * Connect to a ble device. The uuid is the Apple UUID which differs between phones for a single device
     *
     */
    open func connect(_ uuid: String) -> Promise<Void> {
        LOG.info("BLUENET_LIB: starting to connect")
        return Promise<Void> { fulfill, reject in
            if (self.BleState != .poweredOn) {
                reject(BleError.NOT_INITIALIZED)
            }
            else {
                // start the connection
                if (connectedPeripheral != nil) {
                    if (connectedPeripheral!.identifier.uuidString == uuid) {
                        LOG.info("BLUENET_LIB: Already connected to this peripheral")
                        fulfill(());
                    }
                    else {
                        LOG.info("BLUENET_LIB: Something is connected")
                        disconnect()
                            .then{ _ in self._connect(uuid)}
                            .then{ _ in fulfill(())}
                            .catch{ err in reject(err)}
                    }
                }
                // cancel any connection attempt in progress.
                else if (connectingPeripheral != nil) {
                    LOG.info("BLUENET_LIB: connection attempt in progress")
                    abortConnecting()
                        .then{ _ in return self._connect(uuid)}
                        .then{ _ in fulfill(())}
                        .catch{ err in reject(err)}
                }
                else {
                    LOG.info("BLUENET_LIB: connecting...")
                    self._connect(uuid)
                        .then{ _ in fulfill(())}
                        .catch{ err in reject(err)}
                }
            }
        };
    }
    
    
    
    /**
     *  Cancel a pending connection
     *
     */
    func abortConnecting()  -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            LOG.info("BLUENET_LIB: starting to abort pending connection request")
            if let connectingPeripheralVal = connectingPeripheral {
                LOG.info("BLUENET_LIB: pending connection detected")
                // if there was a connection in progress, cancel it with an error
                if (pendingPromise.type == .CONNECT) {
                    LOG.info("BLUENET_LIB: rejecting the connection promise")
                    pendingPromise.reject(BleError.CONNECTION_CANCELLED)
                }
                
                LOG.info("BLUENET_LIB: Waiting to cancel connection....")
                pendingPromise.load(fulfill, reject, type: .CANCEL_PENDING_CONNECTION)
                pendingPromise.setDelayedReject(timeoutDurations.cancelPendingConnection, errorOnReject: .CANCEL_PENDING_CONNECTION_TIMEOUT)
                
                centralManager.cancelPeripheralConnection(connectingPeripheralVal)
                
                // we set it to nil here regardless if the connection abortion fails or not.
                connectingPeripheral = nil
            }
            else {
                fulfill(())
            }
        }
    }
    
    /**
     *  This does the actual connection. It stores the pending promise and waits for the delegate to return.
     *
     */
    func _connect(_ uuid: String) -> Promise<Void> {
        let nsUuid = UUID(uuidString: uuid)
        return Promise<Void> { fulfill, reject in
            if (nsUuid == nil) {
                reject(BleError.INVALID_UUID)
            }
            else {
                // get a peripheral from the known list (TODO: check what happens if it requests an unknown one)
                let uuidArray = [nsUuid!]
                let peripherals = centralManager.retrievePeripherals(withIdentifiers: uuidArray);
                if (peripherals.count == 0) {
                    reject(BleError.CAN_NOT_CONNECT_TO_UUID)
                }
                else {
                    let peripheral = peripherals[0]
                    connectingPeripheral = peripheral
                    connectingPeripheral!.delegate = self
                    
                    // setup the pending promise for connection
                    pendingPromise.load(fulfill, reject, type: .CONNECT)
                    pendingPromise.setDelayedReject(timeoutDurations.connect, errorOnReject: .CONNECT_TIMEOUT)
                    centralManager.connect(connectingPeripheral!, options: nil)

                }
            }
        }
    }
    
    /**
     *  Disconnect from the connected BLE device
     */
    open func disconnect() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            // cancel any pending connections
            if (self.connectingPeripheral != nil) {
                LOG.info("BLUENET_LIB: disconnecting from connecting peripheral")
                abortConnecting()
                    .then{ _ in return self._disconnect() }
                    .then{_ -> Void in fulfill(())}
                    .catch{err in reject(err)}
            }
            else {
                self._disconnect().then{_ -> Void in fulfill(())}.catch{err in reject(err)}
            }
        }
    }
    
    func _disconnect() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            // only disconnect if we are actually connected!
            if (self.connectedPeripheral != nil) {
                LOG.info("BLUENET_LIB: disconnecting from connected peripheral")
                let disconnectPromise = Promise<Void> { success, failure in
                    // in case the connected peripheral has been disconnected beween the start and invocation of this method.
                    if (self.connectedPeripheral != nil) {
                        self.pendingPromise.load(success, failure, type: .DISCONNECT)
                        self.pendingPromise.setDelayedReject(timeoutDurations.disconnect, errorOnReject: .DISCONNECT_TIMEOUT)
                        self.centralManager.cancelPeripheralConnection(self.connectedPeripheral!)
                    }
                    else {
                        success(())
                    }
                }
                // we clean up (self.connectedPeripheral = nil) inside the disconnect() method, thereby needing this inner promise
                disconnectPromise.then { _ -> Void in
                    // make sure the connected peripheral is set to nil so we know nothing is connected
                    self.connectedPeripheral = nil
                    fulfill(())
                }
                .catch { err in reject(err) }
            }
            else {
                fulfill(())
            }
        }
    }

    
    /**
     *  Get the services from a connected device
     *
     */
    open func getServicesFromDevice() -> Promise<[CBService]> {
        return Promise<[CBService]> { fulfill, reject in
            if (connectedPeripheral != nil) {
                if let services = connectedPeripheral!.services {
                    fulfill(services)
                }
                else {
                    self.pendingPromise.load(fulfill, reject, type: .GET_SERVICES)
                    self.pendingPromise.setDelayedReject(timeoutDurations.getServices, errorOnReject: .GET_SERVICES_TIMEOUT)
                    // the fulfil and reject are handled in the peripheral delegate
                    connectedPeripheral!.discoverServices(nil) // then return services
                }
            }
            else {
                reject(BleError.NOT_CONNECTED)
            }
        }
    }
    
    func _getServiceFromList(_ list:[CBService], _ uuid: String) -> CBService? {
        let matchString = uuid.uppercased()
        for service in list {
            if (service.uuid.uuidString == matchString) {
                return service
            }
        }
        return nil;
    }
    
    open func getCharacteristicsFromDevice(_ serviceId: String) -> Promise<[CBCharacteristic]> {
        return Promise<[CBCharacteristic]> { fulfill, reject in
            // if we are not connected, exit
            if (connectedPeripheral != nil) {
                // get all services from connected device (is cached if we already know it)
                self.getServicesFromDevice()
                    // then get all characteristics from connected device (is cached if we already know it)
                    .then {(services: [CBService]) -> Promise<[CBCharacteristic]> in // get characteristics
                        if let service = self._getServiceFromList(services, serviceId) {
                            return self.getCharacteristicsFromDevice(service)
                        }
                        else {
                            throw BleError.SERVICE_DOES_NOT_EXIST
                        }
                    }
                    // then get the characteristic we need if it is in the list.
                    .then {(characteristics: [CBCharacteristic]) -> Void in
                        fulfill(characteristics);
                    }
                    .catch {(error: Error) -> Void in
                        reject(error)
                    }
            }
            else {
                reject(BleError.NOT_CONNECTED)
            }
        }
    }
    
    func getCharacteristicsFromDevice(_ service: CBService) -> Promise<[CBCharacteristic]> {
        return Promise<[CBCharacteristic]> { fulfill, reject in
            if (connectedPeripheral != nil) {
                if let characteristics = service.characteristics {
                    fulfill(characteristics)
                }
                else {
                    self.pendingPromise.load(fulfill, reject, type: .GET_CHARACTERISTICS)
                    self.pendingPromise.setDelayedReject(timeoutDurations.getCharacteristics, errorOnReject: .GET_CHARACTERISTICS_TIMEOUT)

                    // the fulfil and reject are handled in the peripheral delegate
                    connectedPeripheral!.discoverCharacteristics(nil, for: service)// then return services
                }
            }
            else {
                reject(BleError.NOT_CONNECTED)
            }
        }
    }
    
    func getCharacteristicFromList(_ list: [CBCharacteristic], _ uuid: String) -> CBCharacteristic? {
        let matchString = uuid.uppercased()
        for characteristic in list {
            if (characteristic.uuid.uuidString == matchString) {
                return characteristic
            }
        }
        return nil;
    }
    
    func getChacteristic(_ serviceId: String, _ characteristicId: String) -> Promise<CBCharacteristic> {
        return Promise<CBCharacteristic> { fulfill, reject in
            // if we are not connected, exit
            if (connectedPeripheral != nil) {
                // get all services from connected device (is cached if we already know it)
                self.getServicesFromDevice()
                    // then get all characteristics from connected device (is cached if we already know it)
                    .then{(services: [CBService]) -> Promise<[CBCharacteristic]> in
                        if let service = self._getServiceFromList(services, serviceId) {
                            return self.getCharacteristicsFromDevice(service)
                        }
                        else {
                            throw BleError.SERVICE_DOES_NOT_EXIST
                        }
                    }
                    // then get the characteristic we need if it is in the list.
                    .then{(characteristics: [CBCharacteristic]) -> Void in
                        if let characteristic = self.getCharacteristicFromList(characteristics, characteristicId) {
                            fulfill(characteristic)
                        }
                        else {
                            throw BleError.CHARACTERISTIC_DOES_NOT_EXIST
                        }
                    }
                    .catch{err in reject(err)}
            }
            else {
                reject(BleError.NOT_CONNECTED)
            }
        }
    }
    
    open func readCharacteristicWithoutEncryption(_ service: String, characteristic: String) -> Promise<[UInt8]> {
        return Promise<[UInt8]> { fulfill, reject in
            self.settings.disableEncryptionTemporarily()
            self.readCharacteristic(service, characteristicId: characteristic)
                .then{data -> Void in
                    self.settings.restoreEncryption()
                    fulfill(data)
                }
                .catch{(error: Error) -> Void in
                    self.settings.restoreEncryption()
                    reject(error)
                }
        }
    }
    
    open func readCharacteristic(_ serviceId: String, characteristicId: String) -> Promise<[UInt8]> {
        return Promise<[UInt8]> { fulfill, reject in
            self.getChacteristic(serviceId, characteristicId)
                .then{characteristic -> Void in
                    if (self.connectedPeripheral != nil) {
                        self.pendingPromise.load(fulfill, reject, type: .READ_CHARACTERISTIC)
                        self.pendingPromise.setDelayedReject(timeoutDurations.readCharacteristic, errorOnReject: .READ_CHARACTERISTIC_TIMEOUT)
                        
                        // the fulfil and reject are handled in the peripheral delegate
                        self.connectedPeripheral!.readValue(for: characteristic)
                    }
                    else {
                        reject(BleError.NOT_CONNECTED)
                    }
                }
                .catch{err in reject(err)}
        }
    }
    
    open func writeToCharacteristic(_ serviceId: String, characteristicId: String, data: Data, type: CBCharacteristicWriteType) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            self.getChacteristic(serviceId, characteristicId)
                .then{characteristic -> Void in
                    if (self.connectedPeripheral != nil) {
                        self.pendingPromise.load(fulfill, reject, type: .WRITE_CHARACTERISTIC)
                        
                        if (type == .withResponse) {
                            self.pendingPromise.setDelayedReject(timeoutDurations.writeCharacteristic, errorOnReject: .WRITE_CHARACTERISTIC_TIMEOUT)
                        }
                        else {
                            // if we write without notification, the delegate will not be invoked.
                            self.pendingPromise.setDelayedFulfill(timeoutDurations.writeCharacteristicWithout)
                        }
                        
                        // the fulfil and reject are handled in the peripheral delegate
                        if (self.settings.isEncryptionEnabled()) {
                             LOG.debug("BLUENET_LIB: writing \(data.bytes) which will be encrypted.")
                            do {
                                let encryptedData = try EncryptionHandler.encrypt(data, settings: self.settings)
                                self.connectedPeripheral!.writeValue(encryptedData, for: characteristic, type: type)
                            }
                            catch let err {
                                self.pendingPromise.reject(err)
                            }
                        }
                        else {
                            LOG.debug("BLUENET_LIB: writing \(data.bytes)")
                            self.connectedPeripheral!.writeValue(data, for: characteristic, type: type)
                        }
                    }
                    else {
                        reject(BleError.NOT_CONNECTED)
                    }
                }
                .catch{(error: Error) -> Void in
                    LOG.error("BLUENET_LIB: FAILED writing to characteristic \(error)")
                    reject(error)
                }
        }
    }
    
    open func enableNotifications(_ serviceId: String, characteristicId: String, callback: @escaping eventCallback) -> Promise<voidPromiseCallback> {
        var unsubscribeCallback : voidCallback? = nil
        return Promise<voidPromiseCallback> { fulfill, reject in
            // if there is already a listener on this topic, we assume notifications are already enabled. We just add another listener
            if (self.notificationEventBus.hasListeners(serviceId + "_" + characteristicId)) {
                unsubscribeCallback = self.notificationEventBus.on(serviceId + "_" + characteristicId, callback)
                
                // create the cleanup callback and return it.
                let cleanupCallback : voidPromiseCallback = { 
                    return self.disableNotifications(serviceId, characteristicId: characteristicId, unsubscribeCallback: unsubscribeCallback!)
                }
                fulfill(cleanupCallback)
            }
            else {
                // we first get the characteristic from the device
                self.getChacteristic(serviceId, characteristicId)
                    // then we subscribe to the feed before we know it works to miss no data.
                    .then{(characteristic: CBCharacteristic) -> Promise<Void> in
                        unsubscribeCallback = self.notificationEventBus.on(characteristic.service.uuid.uuidString + "_" + characteristic.uuid.uuidString, callback)
                        
                        // we now tell the device to notify us.
                        return Promise<Void> { success, failure in
                            if (self.connectedPeripheral != nil) {
                                // the success and failure are handled in the peripheral delegate
                                self.pendingPromise.load(success, failure, type: .ENABLE_NOTIFICATIONS)
                                self.pendingPromise.setDelayedReject(timeoutDurations.enableNotifications, errorOnReject: .ENABLE_NOTIFICATIONS_TIMEOUT)
                                self.connectedPeripheral!.setNotifyValue(true, for: characteristic)
                            }
                            else {
                                failure(BleError.NOT_CONNECTED)
                            }
                        }
                    }
                    .then{_ -> Void in
                        let cleanupCallback : voidPromiseCallback = { self.disableNotifications(serviceId, characteristicId: characteristicId, unsubscribeCallback: unsubscribeCallback!) }
                        fulfill(cleanupCallback)
                    }
                    .catch{(error: Error) -> Void in
                        // if something went wrong, we make sure the callback will not be fired.
                        if (unsubscribeCallback != nil) {
                            unsubscribeCallback!()
                        }
                        reject(error)
                    }
            }
        }
    }
    
    func disableNotifications(_ serviceId: String, characteristicId: String, unsubscribeCallback: voidCallback) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            // remove the callback
            unsubscribeCallback()
            
            // if there are still other callbacks listening, we're done!
            if (self.notificationEventBus.hasListeners(serviceId + "_" + characteristicId)) {
                fulfill(())
            }
            // if we are no longer connected we dont need to clean up.
            else if (self.connectedPeripheral == nil) {
                fulfill(())
            }
            else {
                // if there are no more people listening, we tell the device to stop the notifications.
                self.getChacteristic(serviceId, characteristicId)
                    .then{characteristic -> Void in
                        if (self.connectedPeripheral == nil) {
                            fulfill(())
                        }
                        else {
                            self.pendingPromise.load(fulfill, reject, type: .DISABLE_NOTIFICATIONS)
                            self.pendingPromise.setDelayedReject(timeoutDurations.disableNotifications, errorOnReject: .DISABLE_NOTIFICATIONS_TIMEOUT)
                            
                            // the fulfil and reject are handled in the peripheral delegate
                            self.connectedPeripheral!.setNotifyValue(false, for: characteristic)
                        }
                    }
                    .catch{(error: Error) -> Void in
                        reject(error)
                    }
            }
        }
    }
    
    
    /**
     * This will just subscribe for a single notification and clean up after itself. 
     * The merged, finalized reply to the write command will be in the fulfill of this promise.
     */
    open func setupSingleNotification(_ serviceId: String, characteristicId: String, writeCommand: @escaping voidPromiseCallback) -> Promise<[UInt8]> {
        return Promise<[UInt8]> { fulfill, reject in
            var unsubscribe : voidPromiseCallback? = nil
            var collectedData = [UInt8]();
            
            // use the notification merger to handle the full packet once we have received it.
            let merger = NotificationMerger(callback: { data -> Void in
                if (self.settings.isEncryptionEnabled()) {
                    do {
                        // attempt to decrypt it
                        let decryptedData = try EncryptionHandler.decrypt(Data(data), settings: self.settings)
                        collectedData = decryptedData.bytes;
                    }
                    catch _ {
                        LOG.error("Error decrypting single notification!")
                    }
                }
                else {
                    collectedData = data
                }
                unsubscribe!()
                    .then{ _  in fulfill(collectedData) }
                    .catch{ err in reject(err) }
            })
            
            
            let notificationCallback = {(data: Any) -> Void in
                if let castData = data as? Data {
                    merger.merge(castData.bytes)
                }
            }
            
            self.enableNotifications(serviceId, characteristicId: characteristicId, callback: notificationCallback)
                .then{ unsub -> Promise<Void> in
                    unsubscribe = unsub
                    return writeCommand()
                }
                .catch{ err in reject(err) }
        }
    }
    
    // MARK: scanning
    
    open func startScanning() {
        self.disableBatterySaving(doNotChangeScanning: true)
        self.scanning = true
        self.scanUniqueOnly = false
        self.scanningForServices = nil
        self.scanningStateStored = true
        
        if (self.decoupledDelegate == true) {
            LOG.info("BLUENET_LIB: ignored startScanning because the delegate is decoupled (likely due to DFU in progress)")
            return
        }
        
        LOG.info("BLUENET_LIB: start scanning everything")
        centralManager.scanForPeripherals(withServices: nil, options:[CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    open func startScanningForService(_ serviceUUID: String, uniqueOnly: Bool = false) {
         self.disableBatterySaving(doNotChangeScanning: true)
        self.scanning = true
        self.scanUniqueOnly = uniqueOnly
        let service = CBUUID(string: serviceUUID)
        self.scanningForServices = [service]
        self.scanningStateStored = true
        
        if (self.decoupledDelegate == true) {
            LOG.info("BLUENET_LIB: ignored startScanningForService because the delegate is decoupled (likely due to DFU in progress)")
            return
        }
        
        LOG.info("BLUENET_LIB: start scanning for services \(serviceUUID)")
        centralManager.scanForPeripherals(withServices: [service], options:[CBCentralManagerScanOptionAllowDuplicatesKey: !uniqueOnly])
    }
    
    open func startScanningForServices(_ serviceUUIDs: [String], uniqueOnly: Bool = false) {
        self.disableBatterySaving(doNotChangeScanning: true)
        self.scanning = true
        self.scanUniqueOnly = uniqueOnly
        var services = [CBUUID]()
        for service in serviceUUIDs {
            services.append(CBUUID(string: service))
        }
        self.scanningStateStored = true
        
        self.scanningForServices = services
        
        if (self.decoupledDelegate == true) {
            LOG.info("BLUENET_LIB: ignored startScanningForServices because the delegate is decoupled (likely due to DFU in progress)")
            return
        }
        
        LOG.info("BLUENET_LIB: start scanning for multiple services \(serviceUUIDs)")
        centralManager.scanForPeripherals(withServices: services, options:[CBCentralManagerScanOptionAllowDuplicatesKey: !uniqueOnly])
    }
    
    open func pauseScanning() {
        LOG.info("BLUENET_LIB: pausing scan")
        centralManager.stopScan()
    }
    

    open func stopScanning() {
        self.scanning = false
        self.scanUniqueOnly = false
        self.scanningForServices = nil
        self.scanningStateStored = true
        
        if (self.decoupledDelegate == true) {
            LOG.info("BLUENET_LIB: ignored stopScanning because the delegate is decoupled (likely due to DFU in progress)")
            return
        }
        
        LOG.info("BLUENET_LIB: stopping scan")
        centralManager.stopScan()
    }
    
    open func restoreScanning() {
        // only restore scanning if we have a valid restoration state.
        if (self.scanningStateStored == false) {
            LOG.info("BLUENET_LIB: Can't restore scanning: no state saved")
            return
        }
        LOG.info("BLUENET_LIB: Restoring scan...")
        
        if (self.scanning == false) {
            self.stopScanning()
        }
        else {
            self.disableBatterySaving(doNotChangeScanning: true)
            centralManager.stopScan()
            centralManager.scanForPeripherals(withServices: self.scanningForServices, options:[CBCentralManagerScanOptionAllowDuplicatesKey: !self.scanUniqueOnly])
        }
    }
    
    // MARK: peripheral delegate
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if (pendingPromise.type == .GET_SERVICES) {
            // we will allow silent errors here if we do not explicitly ask for services
            if (error != nil) {
                pendingPromise.reject(error!)
            }
            else {
                if let services = peripheral.services {
                    pendingPromise.fulfill(services)
                }
                else {
                    pendingPromise.reject(BleError.NO_SERVICES)
                }
            }
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if (pendingPromise.type == .GET_CHARACTERISTICS) {
            // we will allow silent errors here if we do not explicitly ask for characteristics
            if (error != nil) {
                pendingPromise.reject(error!)
            }
            else {
                if let characteristics = service.characteristics {
                    pendingPromise.fulfill(characteristics)
                }
                else {
                    pendingPromise.reject(BleError.NO_CHARACTERISTICS)
                }
            }
        }
    }
    
    /**
    * This is the reaction to read characteristic AND notifications!
    */
    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // handle the case for failed bonding
        if (error != nil) {
            if (pendingPromise.type == .READ_CHARACTERISTIC) {
                pendingPromise.reject(error!)
            }
            return
        }
        
        
        // in case of notifications:
        let serviceId = characteristic.service.uuid.uuidString
        let characteristicId = characteristic.uuid.uuidString
        let topicString = serviceId + "_" + characteristicId
        if (self.notificationEventBus.hasListeners(topicString)) {
            if let data = characteristic.value {
                // notifications are a chopped up encrypted message. We leave decryption for the handling methods.
                self.notificationEventBus.emit(topicString, data)
            }
        }
        
        if (pendingPromise.type == .READ_CHARACTERISTIC) {
            if (error != nil) {
                pendingPromise.reject(error!)
            }
            else {
                if (characteristic.value != nil) {
                    let data = characteristic.value!
                    if (self.settings.isEncryptionEnabled()) {
                        do {
                            let decryptedData = try EncryptionHandler.decrypt(data, settings: self.settings)
                            pendingPromise.fulfill(decryptedData.bytes)
                        }
                        catch let err {
                            pendingPromise.reject(err)
                        }
                    }
                    else {
                        pendingPromise.fulfill(data.bytes)
                    }
                }
                else {
                    pendingPromise.fulfill([UInt8]())
                }
            }
        }
    }
    
    
    
    open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        LOG.info("BLUENET_LIB: written")
        if (pendingPromise.type == .WRITE_CHARACTERISTIC) {
            if (error != nil) {
                pendingPromise.reject(error!)
            }
            else {
                pendingPromise.fulfill(())
            }
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if (pendingPromise.type == .ENABLE_NOTIFICATIONS || pendingPromise.type == .DISABLE_NOTIFICATIONS) {
            if (error != nil) {
                pendingPromise.reject(error!)
            }
            else {
                pendingPromise.fulfill(())
            }
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        peripheral.discoverServices(nil)
    }
    
    
    
    
}

