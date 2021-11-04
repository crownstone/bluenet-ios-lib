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



struct timeoutDurations {
    static let disconnect              : Double = 3
    static let errorDisconnect         : Double = 5
    static let cancelPendingConnection : Double = 2
    static let connect                 : Double = 30
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

let semaphore = DispatchSemaphore(value: 1)
let isConnectedSemaphore = DispatchSemaphore(value: 1)

public class BleManager: NSObject, CBPeripheralDelegate {
    public var centralManager : CBCentralManager!
    var peripheralStateManager : PeripheralStateManager!
    
    var _connectionStates = [String: ConnectionState]()
    var _tasks = [String: PromiseContainer]()
    var _notificationEventBusses = [String: EventBus]()
    
    var BleState : CBManagerState = .unknown
    
    var pendingConnections = [String: CBPeripheral]()
    var connections        = [String: CBPeripheral]()
    
    var eventBus : EventBus!
    
    public var settings : BluenetSettings!
    
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

    public init(peripheralStateManager: PeripheralStateManager, eventBus: EventBus, settings: BluenetSettings, backgroundEnabled: Bool = true) {
        super.init();
        self.peripheralStateManager = peripheralStateManager
        self.settings = settings
        self.eventBus = eventBus
        
        self.backgroundEnabled = backgroundEnabled
        
        self.CBDelegate = BluenetCBDelegate(bleManager: self)
        self.CBDelegateBackground = BluenetCBDelegateBackground(bleManager: self)
        self.setCentralManager()
        
        
        // initialize the pending promise containers
        _ = self.eventBus.on("bleStatus", self._handleStateUpdate)
    }
    
    func task(_ handle: UUID) -> PromiseContainer {
        return self.task(handle.uuidString)
    }
    
    func connectionState(_ handle: UUID) -> ConnectionState {
        return self.connectionState(handle.uuidString)
    }
    
    func notificationBus(_ handle: UUID) -> EventBus {
        return self.notificationBus(handle.uuidString)
    }
    
    
    func task(_ handle: String) -> PromiseContainer {
        semaphore.wait()
        if let task = self._tasks[handle] {
            LOG.info("Returning task for \(handle)")
            semaphore.signal()
            return task
        }
        
        let task = PromiseContainer(handle)
        self._tasks[handle] = task
        LOG.info("Creating task for \(handle)")
        semaphore.signal()
        return task
    }
    
    func connectionState(_ handle: String) -> ConnectionState {
        semaphore.wait()
        if let state = self._connectionStates[handle] {
            semaphore.signal()
            return state
        }
        
        let state = ConnectionState(bleManager: self, handle: handle)
        self._connectionStates[handle] = state
        semaphore.signal()
        return state
    }
    
    func notificationBus(_ handle: String) -> EventBus {
        semaphore.wait()
        if let bus = self._notificationEventBusses[handle] {
            semaphore.signal()
            return bus
        }
        
        let bus = EventBus()
        self._notificationEventBusses[handle] = bus
        semaphore.signal()
        return bus
    }
    
    func isConnected(_ handle: UUID) -> Bool {
        return self.isConnected(handle.uuidString)
    }
    
    func isConnected(_ handle: String) -> Bool {
        isConnectedSemaphore.wait()
        let state = self.connections.keys.contains(handle)
        isConnectedSemaphore.signal()
        return state
    }
    
    
    
    func isConnecting(_ handle: UUID) -> Bool {
        return self.isConnecting(handle.uuidString)
    }
    
    func isConnecting(_ handle: String) -> Bool {
        isConnectedSemaphore.wait()
        let state = self.pendingConnections.keys.contains(handle)
        isConnectedSemaphore.signal()
        return state
    }
    
    func _handleStateUpdate(_ state: Any) {
        LOG.info("BLUENET_LIB: Handling a state update \(state)")
        if let stateStr = state as? String {
            LOG.info("BLUENET_LIB: Handling a state update for state: \(stateStr)")
            switch (stateStr) {
            case "resetting", "poweredOff":
                LOG.info("BLUENET_LIB: Cleaning up after BLE reset.")
                      
                for (_, promiseManager) in self._tasks {
                    promiseManager.clearDueToReset()
                }
                
                self.pendingConnections = [String: CBPeripheral]()
                self.connections        = [String: CBPeripheral]()
                
            default:
                break
            }
        }
    }
    
    public func setBackgroundOperations(newBackgroundState: Bool) {
        if (self.backgroundEnabled == newBackgroundState) {
            return
        }
        centralManager.stopScan()
        self.backgroundEnabled = newBackgroundState
        self.BleState = .unknown
        self.cBmanagerUpdatedState = false
        self.setCentralManager()
        
        self.isReady().done{ _ in self.restoreScanning()}.catch{ err in print(err) }
        
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
                options: [CBCentralManagerOptionShowPowerAlertKey: true, CBCentralManagerOptionRestoreIdentifierKey: APPNAME + "BluenetIOS"]
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
    public func enableBatterySaving(doNotChangeScanning: Bool = false) {
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
    public func disableBatterySaving(doNotChangeScanning : Bool = false) {
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
    
    public func decoupleFromDelegate() {
        LOG.info("Decoupling from Delegate")
        self.decoupledDelegate = true
    }
    
    public func reassignDelegate() {
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
   
    public func emitBleState() {
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
    public func isReady() -> Promise<Void> {
        return Promise<Void> { seal in
            if (self.BleState != .poweredOn) {
                delay(0.50, { _ = self.isReady().done{_ -> Void in seal.fulfill(())} })
            }
            else {
                seal.fulfill(())
            }
        }
    }
    
    public func wait(seconds: Double) -> Promise<Void> {
        return Promise<Void> { seal in
            delay(seconds, { seal.fulfill(()) })
        }
    }
    
    public func waitToReconnect() -> Promise<Void> {
        return Promise<Void> { seal in
            delay(timeoutDurations.waitForReconnect, { seal.fulfill(()) })
        }
    }
    
    public func waitForRestart() -> Promise<Void> {
        return Promise<Void> { seal in
            delay(timeoutDurations.waitForRestart, { seal.fulfill(()) })
        }
    }
    
    // this delay is set up for calls that need to write to storage.
    public func waitToWrite(_ iteration: UInt8 = 0) -> Promise<Void> {
        if (iteration > 0) {
            LOG.info("BLUENET_LIB: Could not verify immediatly, waiting longer between steps...")
            return Promise<Void> { seal in
                delay(2 * timeoutDurations.waitForWrite, { seal.fulfill(()) })
            }
        }
        
        return Promise<Void> { seal in
            delay(timeoutDurations.waitForWrite, { seal.fulfill(()) })
        }
    }

    
    public func getPeripheral(_ handle: String) -> CBPeripheral? {
        let nsUuid = UUID(uuidString: handle)
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
     * Connect to a ble device. The handle is the Apple UUID which differs between phones for a single device
     */
    public func connect(_ handle: String, timeout: Double = 0) -> Promise<Void> {
        if let nsUUID = UUID(uuidString: handle) {
            LOG.info("BLUENET_LIB: starting to connect \(handle).")
            return Promise<Void> { seal in
                if (self.BleState != .poweredOn) {
                    LOG.error("BLUENET_LIB: BLE OFF \(handle).")
                    return seal.reject(BluenetError.NOT_INITIALIZED)
                }
                
                
                if (self.pendingConnections[nsUUID.uuidString] != nil) {
                    LOG.info("BLUENET_LIB: Already connecting to this peripheral. This throws an error to avoid multiple triggers on successful completion.  \(handle).")
                    return seal.reject(BluenetError.ALREADY_CONNECTING)
                }
                    
                LOG.info("BLUENET_LIB: connecting...  \(handle).")
                self._connect(nsUUID)
                    .done{    _ in seal.fulfill(())}
                    .catch{ err in seal.reject(err)}
            }
        }
        else {
            LOG.error("BLUENET_LIB: Invalid uuid \(handle).")
            return Promise<Void> { seal in seal.reject(BluenetError.INVALID_UUID)}
        }
    }
    
    
    
   
    
    
    /**
     *  This does the actual connection. It stores the pending promise and waits for the delegate to return.
     */
    func _connect(_ handle: UUID, timeout: Double = 0) -> Promise<Void> {
        return Promise<Void> { seal in
            // get a peripheral from the known list (TODO: check what happens if it requests an unknown one)
            let uuidArray = [handle]
            
            semaphore.wait()
            let peripherals = self.centralManager.retrievePeripherals(withIdentifiers: uuidArray);
            if (peripherals.count == 0) {
                semaphore.signal()
                LOG.error("BLUENET_LIB: Can not get peripheral \(BluenetError.CAN_NOT_CONNECT_TO_UUID) \(handle)")
                seal.reject(BluenetError.CAN_NOT_CONNECT_TO_UUID)
            }
            else {
                let peripheral = peripherals[0]
                self.pendingConnections[handle.uuidString] = peripheral
                semaphore.signal()
                
                peripheral.delegate = self
                
                // setup the pending promise for connection
                self.task(handle).load(seal.fulfill, seal.reject, type: .CONNECT)
                if (timeout > 0) {
                    self.task(handle).setDelayedReject(timeoutDurations.connect, errorOnReject: .CONNECT_TIMEOUT)
                }
                LOG.info("BLUENET_LIB: Starting connection to \(handle)")
                
                var connectionOptions : [String: Any]? = nil
                connectionOptions = [
                    "CBConnectPeripheralOptionEnableTransportBridgingKey": false,
                    "CBConnectPeripheralOptionStartDelayKey": NSNumber(value: 0)
                ]
                self.centralManager.connect(peripheral, options: connectionOptions)
            }
        }
    }
    
    
    /**
     *  Cancel a pending connection
     */
    func abortConnecting(_ handle: String) {
        LOG.info("BLUENET_LIB: starting to abort pending connection request for \(handle)")

        // if there was a connection in progress, cancel it with an error
        if (task(handle).type == .CONNECT) {
            LOG.info("BLUENET_LIB: rejecting the connection promise for \(handle)")
            task(handle).reject(BluenetError.CONNECTION_CANCELLED)
        }
        
        // remove peripheral from pending list.
        if let connectingPeripheral = self.pendingConnections[handle] {
            LOG.info("BLUENET_LIB: Waiting to cancel connection... for \(handle).")
            self.centralManager.cancelPeripheralConnection(connectingPeripheral)
            
            // accessing shared resources.
            semaphore.wait()
            self.pendingConnections.removeValue(forKey: handle)
            semaphore.signal()
        }
        else if self.isConnected(handle) {
            self.disconnect(handle)
                .catch{ _ in }
        }
    }
    
    
    
    public func waitForPeripheralToDisconnect(_ handle: UUID, timeout : Double) -> Promise<Void> {
        return Promise<Void> { seal in
            // only disconnect if we are actually connected!
            if self.isConnected(handle) {
                LOG.info("BLUENET_LIB: waiting for the connected peripheral to disconnect from us \(handle)")
                let disconnectPromise = Promise<Void> { innerSeal in
                    // in case the connected peripheral has been disconnected beween the start and invocation of this method.
                    self.task(handle).load(innerSeal.fulfill, innerSeal.reject, type: .AWAIT_DISCONNECT)
                    self.task(handle).setDelayedReject(timeout, errorOnReject: .AWAIT_DISCONNECT_TIMEOUT)
                }
                // we clean up (self.connectedPeripheral = nil) inside the disconnect() method, thereby needing this inner promise
                disconnectPromise.done { _ -> Void in
                    // make sure the connected peripheral is set to nil so we know nothing is connected
                    semaphore.wait()
                    self.connections.removeValue(forKey: handle.uuidString)
                    semaphore.signal()
                    seal.fulfill(())
                }
                .catch { err in seal.reject(err) }
            }
            else {
                seal.fulfill(())
            }
        }
    }

    /**
     *  Disconnect from the connected BLE device
     */
    public func errorDisconnect(_ handle: String) -> Promise<Void> {
        if let uuidHandle = UUID(uuidString: handle) {
            let handleString = uuidHandle.uuidString
            return Promise<Void> { seal in
                // cancel any pending connections
                if (self.pendingConnections[handleString] != nil) {
                    LOG.info("BLUENET_LIB: disconnecting from connecting peripheral due to error \(handle)")
                    self.abortConnecting(uuidHandle.uuidString)
                    self._disconnect(handleString, errorMode: true)
                        .done{_ -> Void in seal.fulfill(())}
                        .catch{err in seal.reject(err)}
                }
                else {
                    self._disconnect(handleString, errorMode: true)
                        .done{_ -> Void in seal.fulfill(())}
                        .catch{err in seal.reject(err)}
                }
            }
        }
        else {
            return Promise<Void> { seal in seal.reject(BluenetError.INVALID_UUID) }
        }
    }

    /**
     *  Disconnect from the connected BLE device
     */
    public func disconnect(_ handle: String) -> Promise<Void> {
        if let uuidHandle = UUID(uuidString: handle) {
            let handleString = uuidHandle.uuidString
            return Promise<Void> { seal in
                // cancel any pending connections
                if (self.pendingConnections[handleString] != nil) {
                    LOG.info("BLUENET_LIB: disconnecting from connecting peripheral \(handleString)")
                    abortConnecting(handleString)
                    self._disconnect(handleString)
                        .done{_ -> Void in seal.fulfill(())}
                        .catch{err in seal.reject(err)}
                }
                else {
                    self._disconnect(handleString)
                        .done{_ -> Void in seal.fulfill(())}
                        .catch{err in seal.reject(err)}
                }
            }
        }
        else {
            return Promise<Void> { seal in seal.reject(BluenetError.INVALID_UUID) }
        }
    }


    func _disconnect(_ handle: String, errorMode: Bool = false) -> Promise<Void> {
        return Promise<Void> { seal in
            if let uuidHandle = UUID(uuidString: handle) {
                // only disconnect if we are actually connected!
                if self.isConnected(handle) {
                    LOG.info("BLUENET_LIB: disconnecting from connected peripheral \(handle)")
                    self._disconnectFromDevice(handle, errorMode: errorMode)
                        .done { _ -> Void in
                            // make sure the connected peripheral is set to nil so we know nothing is connected
                            semaphore.wait()
                            self.connections.removeValue(forKey: uuidHandle.uuidString)
                            semaphore.signal()
                            seal.fulfill(())
                        }
                        .catch { err in seal.reject(err) }
                }
                else {
                    seal.fulfill(())
                }
            }
            else {
                seal.reject(BluenetError.INVALID_UUID)
            }
        }
    }
    
    func _disconnectFromDevice(_ handle: String, errorMode: Bool = false) -> Promise<Void> {
        return Promise<Void> { seal in
            if let uuidHandle = UUID(uuidString: handle) {
                // in case the connected peripheral has been disconnected beween the start and invocation of this method.
                semaphore.wait()
                if let connection = self.connections[uuidHandle.uuidString] {
                    self.centralManager.cancelPeripheralConnection(connection)
                    semaphore.signal()
                    LOG.info("BLUENET_LIB: disconnecting from connected peripheral in _disconnectFromDevice \(handle) \(errorMode)")
                    if (errorMode == true) {
                        self.task(handle).load(seal.fulfill, seal.reject, type: .ERROR_DISCONNECT)
                        self.task(handle).setDelayedReject(timeoutDurations.errorDisconnect, errorOnReject: .ERROR_DISCONNECT_TIMEOUT)
                    }
                    else {
                        self.task(handle).load(seal.fulfill, seal.reject, type: .DISCONNECT)
                        self.task(handle).setDelayedReject(timeoutDurations.disconnect, errorOnReject: .DISCONNECT_TIMEOUT)
                    }
                }
                else {
                    semaphore.signal()
                    seal.fulfill(())
                }
            }
            else {
                seal.reject(BluenetError.INVALID_UUID)
            }
        }
    }


    /**
     *  Get the services from a connected device
     *
     */
    public func getServicesFromDevice(_ handle: UUID) -> Promise<[CBService]> {
        return Promise<[CBService]> { seal in
            semaphore.wait()
            if let connection = self.connections[handle.uuidString] {
                if let services = connection.services {
                    semaphore.signal()
                    seal.fulfill(services)
                }
                else {
                    semaphore.signal()
                    self.task(handle).load(seal.fulfill, seal.reject, type: .GET_SERVICES)
                    self.task(handle).setDelayedReject(timeoutDurations.getServices, errorOnReject: .GET_SERVICES_TIMEOUT)
                    // the fulfil and reject are handled in the peripheral delegate
                    connection.discoverServices(nil) // then return services
                }
            }
            else {
                semaphore.signal()
                seal.reject(BluenetError.NOT_CONNECTED)
            }
        }
    }

    
    public func getCharacteristicsFromDevice(_ handle: UUID, serviceId: String) -> Promise<[CBCharacteristic]> {
        return Promise<[CBCharacteristic]> { seal in
            // if we are not connected, exit
            if self.isConnected(handle) {
                // get all services from connected device (is cached if we already know it)
                self.getServicesFromDevice(handle)
                    // then get all characteristics from connected device (is cached if we already know it)
                    .then {(services: [CBService]) -> Promise<[CBCharacteristic]> in // get characteristics
                        if let service = getServiceFromList(services, serviceId) {
                            return self.getCharacteristicsFromDevice(handle, service: service)
                        }
                        else {
                            throw BluenetError.SERVICE_DOES_NOT_EXIST
                        }
                    }
                    // then get the characteristic we need if it is in the list.
                    .done {(characteristics: [CBCharacteristic]) -> Void in
                        seal.fulfill(characteristics);
                    }
                    .catch {(error: Error) -> Void in
                        seal.reject(error)
                    }
            }
            else {
                seal.reject(BluenetError.NOT_CONNECTED)
            }
        }
    }

    func getCharacteristicsFromDevice(_ handle: UUID, service: CBService) -> Promise<[CBCharacteristic]> {
        return Promise<[CBCharacteristic]> { seal in
            semaphore.wait()
            if let connection = self.connections[handle.uuidString] {
                if let characteristics = service.characteristics {
                    semaphore.signal()
                    seal.fulfill(characteristics)
                }
                else {
                    // the fulfil and reject are handled in the peripheral delegate
                    connection.discoverCharacteristics(nil, for: service)// then return services
                    semaphore.signal()
                    
                    self.task(handle).load(seal.fulfill, seal.reject, type: .GET_CHARACTERISTICS)
                    self.task(handle).setDelayedReject(timeoutDurations.getCharacteristics, errorOnReject: .GET_CHARACTERISTICS_TIMEOUT)
                }
            }
            else {
                semaphore.signal()
                seal.reject(BluenetError.NOT_CONNECTED)
            }
        }
    }



    func getChacteristic(_ handle: UUID, _ serviceId: String, _ characteristicId: String) -> Promise<CBCharacteristic> {
        return Promise<CBCharacteristic> { seal in
            // if we are not connected, exit
            if self.isConnected(handle) {
                // get all services from connected device (is cached if we already know it)
                self.getServicesFromDevice(handle)
                    // then get all characteristics from connected device (is cached if we already know it)
                    .then{(services: [CBService]) -> Promise<[CBCharacteristic]> in
                        if let service = getServiceFromList(services, serviceId) {
                            return self.getCharacteristicsFromDevice(handle, service: service)
                        }
                        else {
                            throw BluenetError.SERVICE_DOES_NOT_EXIST
                        }
                    }
                    // then get the characteristic we need if it is in the list.
                    .done{(characteristics: [CBCharacteristic]) -> Void in
                        if let characteristic = getCharacteristicFromList(characteristics, characteristicId) {
                            seal.fulfill(characteristic)
                        }
                        else {
                            throw BluenetError.CHARACTERISTIC_DOES_NOT_EXIST
                        }
                    }
                    .catch{err in seal.reject(err)}
            }
            else {
                seal.reject(BluenetError.NOT_CONNECTED)
            }
        }
    }

    public func readCharacteristicWithoutEncryption(_ handle: UUID, service: String, characteristic: String) -> Promise<[UInt8]> {
        LOG.debug("BLUENET_LIB: Reading from Characteristic without Encryption.  handle:\(handle) Service:\(service) Characteristic:\(characteristic)")
        return Promise<[UInt8]> { seal in
            self.connectionState(handle).disableEncryptionTemporarily()
            self.readCharacteristic(handle, serviceId: service, characteristicId: characteristic)
                .done{data -> Void in
                    self.connectionState(handle).restoreEncryption()
                    seal.fulfill(data)
                }
                .catch{(error: Error) -> Void in
                    self.connectionState(handle).restoreEncryption()
                    seal.reject(error)
                }
        }
    }

    public func readCharacteristic(_ handle: UUID, serviceId: String, characteristicId: String) -> Promise<[UInt8]> {
        LOG.debug("BLUENET_LIB: Reading from Characteristic. handle:\(handle) Service:\(serviceId) Characteristic:\(characteristicId)")
        return Promise<[UInt8]> { seal in
            self.getChacteristic(handle, serviceId, characteristicId)
                .done{characteristic -> Void in
                    semaphore.wait()
                    if let connection = self.connections[handle.uuidString] {
                        // the fulfil and reject are handled in the peripheral delegate
                        connection.readValue(for: characteristic)
                        semaphore.signal()
                        
                        self.task(handle).load(seal.fulfill, seal.reject, type: .READ_CHARACTERISTIC)
                        self.task(handle).setDelayedReject(timeoutDurations.readCharacteristic, errorOnReject: .READ_CHARACTERISTIC_TIMEOUT)
                    }
                    else {
                        semaphore.signal()
                        seal.reject(BluenetError.NOT_CONNECTED)
                    }
                }
                .catch{err in seal.reject(err)}
        }
    }

    public func writeToCharacteristic(_ handle: UUID, serviceId: String, characteristicId: String, data: Data, type: CBCharacteristicWriteType) -> Promise<Void> {
        return Promise<Void> { seal in
            self.getChacteristic(handle, serviceId, characteristicId)
                .done{characteristic -> Void in
                    // this method looks like it has a lot of duplicated code, but due to the semaphore guarding the task, connectionState and connection, there can be multiple paths.
                    if self.isConnected(handle) {
                        self.task(handle).load(seal.fulfill, seal.reject, type: .WRITE_CHARACTERISTIC)

                        if (type == .withResponse) {
                            self.task(handle).setDelayedReject(timeoutDurations.writeCharacteristic, errorOnReject: .WRITE_CHARACTERISTIC_TIMEOUT)
                        }
                        else {
                            // if we write without notification, the delegate will not be invoked.
                            self.task(handle).setDelayedFulfill(timeoutDurations.writeCharacteristicWithout)
                        }

                        // the fulfil and reject are handled in the peripheral delegate
                        if (self.connectionState(handle).isEncryptionEnabled()) {
                            LOG.info("BLUENET_LIB: writing service \(serviceId) characteristic \(characteristicId) data: \(data.bytes) which will be encrypted with level: \(self.connectionState(handle).userLevel) handle:\(handle)")
                            do {
                                let encryptedData = try EncryptionHandler.encrypt(data, connectionState: self.connectionState(handle))
                                
                                semaphore.wait()
                                if let connection = self.connections[handle.uuidString] {
                                    connection.writeValue(encryptedData, for: characteristic, type: type)
                                    semaphore.signal()
                                }
                                else {
                                    semaphore.signal()
                                    throw BluenetError.NOT_CONNECTED
                                }
                            }
                            catch let err {
                                self.task(handle).reject(err)
                            }
                        }
                        else {
                            LOG.debug("BLUENET_LIB: writing service \(serviceId) characteristic \(characteristicId) data: \(data.bytes) which is not encrypted. handle:\(handle)")
                            if let connection = self.connections[handle.uuidString] {
                                connection.writeValue(data, for: characteristic, type: type)
                                semaphore.signal()
                            }
                            else {
                                semaphore.signal()
                                seal.reject(BluenetError.NOT_CONNECTED)
                            }
                        }
                    }
                    else {
                        seal.reject(BluenetError.NOT_CONNECTED)
                    }
                }
                .catch{(error: Error) -> Void in
                    LOG.error("BLUENET_LIB: FAILED writing to characteristic \(error) handle:\(handle)")
                    seal.reject(error)
                }
        }
    }

    public func enableNotifications(_ handle: UUID, serviceId: String, characteristicId: String, callback: @escaping eventCallback) -> Promise<voidPromiseCallback> {
        var unsubscribeCallback : voidCallback? = nil
        return Promise<voidPromiseCallback> { seal in
            // if there is already a listener on this topic, we assume notifications are already enabled. We just add another listener
            if (self.notificationBus(handle).hasListeners(serviceId + "_" + characteristicId)) {
                unsubscribeCallback = self.notificationBus(handle).on(serviceId + "_" + characteristicId, callback)

                // create the cleanup callback and return it.
                let cleanupCallback : voidPromiseCallback = {
                    return self.disableNotifications(handle, serviceId: serviceId, characteristicId: characteristicId, unsubscribeCallback: unsubscribeCallback!)
                }
                seal.fulfill(cleanupCallback)
            }
            else {
                // we first get the characteristic from the device
                self.getChacteristic(handle, serviceId, characteristicId)
                    // then we subscribe to the feed before we know it works to miss no data.
                    .then{(characteristic: CBCharacteristic) -> Promise<Void> in
                        unsubscribeCallback = self.notificationBus(handle).on(characteristic.service!.uuid.uuidString + "_" + characteristic.uuid.uuidString, callback)

                        // we now tell the device to notify us.
                        return Promise<Void> { innerSeal in
                            semaphore.wait()
                            if let connection = self.connections[handle.uuidString] {
                                // the success and failure are handled in the peripheral delegate
                                connection.setNotifyValue(true, for: characteristic)
                                semaphore.signal()
                                self.task(handle).load(innerSeal.fulfill, innerSeal.reject, type: .ENABLE_NOTIFICATIONS)
                                self.task(handle).setDelayedReject(timeoutDurations.enableNotifications, errorOnReject: .ENABLE_NOTIFICATIONS_TIMEOUT)
                                
                            }
                            else {
                                semaphore.signal()
                                innerSeal.reject(BluenetError.NOT_CONNECTED)
                            }
                        }
                    }
                    .done{_ -> Void in
                        let cleanupCallback : voidPromiseCallback = { self.disableNotifications(handle, serviceId: serviceId, characteristicId: characteristicId, unsubscribeCallback: unsubscribeCallback!) }
                        seal.fulfill(cleanupCallback)
                    }
                    .catch{(error: Error) -> Void in
                        // if something went wrong, we make sure the callback will not be fired.
                        if (unsubscribeCallback != nil) {
                            unsubscribeCallback!()
                        }
                        seal.reject(error)
                    }
            }
        }
    }

    func disableNotifications(_ handle: UUID, serviceId: String, characteristicId: String, unsubscribeCallback: voidCallback) -> Promise<Void> {
        return Promise<Void> { seal in
            // remove the callback
            unsubscribeCallback()

            // if there are still other callbacks listening, we're done!
            if (self.notificationBus(handle).hasListeners(serviceId + "_" + characteristicId)) {
                seal.fulfill(())
            }
            else if self.isConnected(handle) {
                // if there are no more people listening, we tell the device to stop the notifications.
                self.getChacteristic(handle, serviceId, characteristicId)
                    .done{characteristic -> Void in
                        semaphore.wait()
                        if let connection = self.connections[handle.uuidString] {
                            // the fulfil and reject are handled in the peripheral delegate
                            connection.setNotifyValue(false, for: characteristic)
                            semaphore.signal()
                            
                            self.task(handle).load(seal.fulfill, seal.reject, type: .DISABLE_NOTIFICATIONS)
                            self.task(handle).setDelayedReject(timeoutDurations.disableNotifications, errorOnReject: .DISABLE_NOTIFICATIONS_TIMEOUT)
                        }
                        else {
                            semaphore.signal()
                            seal.fulfill(())
                        }
                    }
                    .catch{(error: Error) -> Void in
                        seal.reject(error)
                    }
            }
            else {
                // if we are no longer connected we dont need to clean up.
                seal.fulfill(())
            }
        }
    }


    /**
     * This will just subscribe for a single notification and clean up after itself.
     * The merged, finalized reply to the write command will be in the fulfill of this promise.
     */
    public func setupSingleNotification(_ handle: UUID, serviceId: String, characteristicId: String, writeCommand: @escaping voidPromiseCallback, timeoutSeconds: Double = 2) -> Promise<[UInt8]> {
        var unsubscribe : voidPromiseCallback = { return Promise.value(()) }
        
        LOG.debug("BLUENET_LIB: Setting up single notification on service: \(serviceId) and characteristic \(characteristicId) for \(handle)")
        return Promise<[UInt8]> { seal in            
            var collectedData = [UInt8]();
            var resolved = false

            // use the notification merger to handle the full packet once we have received it.
            let merger = NotificationMerger(callback: { data -> Void in
                if (self.connectionState(handle).isEncryptionEnabled()) {
                    do {
                        // attempt to decrypt it
                        let decryptedData = try EncryptionHandler.decrypt(Data(data), connectionState: self.connectionState(handle))
                        collectedData = decryptedData.bytes;
                        LOG.debug("Successfully decrypted data: \(collectedData) from \(handle)")
                    }
                    catch let err  {
                        LOG.error("Error decrypting single notification! Original data: \(data) err: \(err) from \(handle)")
                    }
                }
                else {
                    collectedData = data
                    LOG.debug("Successfully combined data: \(collectedData) from \(handle)")
                }
                resolved = true
                unsubscribe()
                    .done{ _  in seal.fulfill(collectedData) }
                    .catch{ err in seal.reject(err) }
            })


            let notificationCallback = {(data: Any) -> Void in
                if let castData = data as? Data {
                    merger.merge(castData.bytes)
                }
            }

            self.enableNotifications(handle, serviceId: serviceId, characteristicId: characteristicId, callback: notificationCallback)
                .then{ unsub -> Promise<Void> in
                    unsubscribe = unsub
                    delay(timeoutSeconds, {
                        if (resolved == false) {
                            seal.reject(BluenetError.TIMEOUT)
                            _ = unsubscribe()
                        }
                    })
                    return writeCommand()
                }
                .catch{ err in seal.reject(err) }
        }
    }

    /**
     * This will just subscribe for a single notification and clean up after itself.
     * The merged, finalized reply to the write command will be in the fulfill of this promise.
     */
    public func setupNotificationStream(_ handle: UUID, serviceId: String, characteristicId: String, writeCommand: @escaping voidPromiseCallback, resultHandler: @escaping processCallback, timeout: Double = 5, successIfWriteSuccessful: Bool = false) -> Promise<Void> {
        return Promise<Void> { seal in
            var unsubscribe : voidPromiseCallback? = nil
            var streamFinished = false
            var writeSuccessful = false

            // use the notification merger to handle the full packet once we have received it.
            let merger = NotificationMerger(callback: { data -> Void in
                var collectedData : [UInt8]? = nil
                if (streamFinished == true) { return }

                if (self.connectionState(handle).isEncryptionEnabled()) {
                    do {
                        // attempt to decrypt it
                        let decryptedData = try EncryptionHandler.decrypt(Data(data), connectionState: self.connectionState(handle))
                        collectedData = decryptedData.bytes;
                        LOG.debug("Successfully decrypted data: \(String(describing: collectedData)) from \(handle)")
                    }
                    catch {
                        LOG.error("Error decrypting notifcation in stream! \(error) from \(handle)")
                        seal.reject(BluenetError.COULD_NOT_DECRYPT)
                        return
                    }
                }
                else {
                    collectedData = data
                    LOG.debug("Successfully combined data: \(String(describing: collectedData))  from \(handle)")
                }



                if let data = collectedData {
                    let result = resultHandler(data)
                    if (result == .FINISHED) {
                        streamFinished = true
                        unsubscribe!()
                            .done{ _  in seal.fulfill(()) }
                            .catch{ err in seal.reject(err) }
                    }
                    else if (result == .CONTINUE) {
                        // do nothing.
                    }
                    else if (result == .ABORT_ERROR) {
                        streamFinished = true
                        unsubscribe!()
                            .done{ _  in seal.reject(BluenetError.PROCESS_ABORTED_WITH_ERROR) }
                            .catch{ err in seal.reject(err) }
                    }
                    else {
                        streamFinished = true
                        unsubscribe!()
                            .done{ _  in seal.reject(BluenetError.UNKNOWN_PROCESS_TYPE) }
                            .catch{ err in seal.reject(err) }
                    }
                }
            })


            let notificationCallback = {(data: Any) -> Void in
                if let castData = data as? Data {
                    merger.merge(castData.bytes)
                }
            }

            delay(timeout, { () in
                if (streamFinished == false) {
                    streamFinished = true
                    if (unsubscribe != nil) {
                        unsubscribe!()
                            .done{ _ -> Void in
                                if (successIfWriteSuccessful && writeSuccessful) {
                                    seal.fulfill(())
                                }
                                else {
                                    seal.reject(BluenetError.NOTIFICATION_STREAM_TIMEOUT)
                                }
                            }
                            .catch{ err in
                                if (successIfWriteSuccessful && writeSuccessful) {
                                    seal.fulfill(())
                                }
                                else {
                                    seal.reject(BluenetError.NOTIFICATION_STREAM_TIMEOUT)
                                }
                        }
                    }
                }
            })

            self.enableNotifications(handle, serviceId: serviceId, characteristicId: characteristicId, callback: notificationCallback)
                .then{ unsub -> Promise<Void> in
                    unsubscribe = unsub
                    return writeCommand()
                }
                .done{ _ -> Void in
                    writeSuccessful = true
                }
                .catch{ err in seal.reject(err) }
        }
    }
    
    // MARK: scanning
    
    public func startScanning() {
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
    
    public func startScanningForService(_ serviceUUID: String, uniqueOnly: Bool = false) {
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
    
    public func startScanningForServices(_ serviceUUIDs: [String], uniqueOnly: Bool = false) {
        var services = [CBUUID]()
        for service in serviceUUIDs {
            services.append(CBUUID(string: service))
        }
        self.startScanningForServicesCBUUID(services, uniqueOnly: uniqueOnly)
    }
    
    public func startScanningForServicesCBUUID(_ services: [CBUUID], uniqueOnly: Bool = false) {
        self.disableBatterySaving(doNotChangeScanning: true)
        self.scanning = true
        self.scanUniqueOnly = uniqueOnly
        self.scanningStateStored = true
        
        self.scanningForServices = services
        
        if (self.decoupledDelegate == true) {
            LOG.info("BLUENET_LIB: ignored startScanningForServices because the delegate is decoupled (likely due to DFU in progress)")
            return
        }
        
        LOG.info("BLUENET_LIB: start scanning for multiple services \(services)")
        centralManager.scanForPeripherals(withServices: services, options:[CBCentralManagerScanOptionAllowDuplicatesKey: !uniqueOnly])
    }
    
    
    public func pauseScanning() {
        LOG.info("BLUENET_LIB: pausing scan")
        centralManager.stopScan()
    }
    

    public func stopScanning() {
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
    
    public func restoreScanning() {
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
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let handle = peripheral.identifier
        
        if (self.task(handle).type == .GET_SERVICES) {
            // we will allow silent errors here if we do not explicitly ask for services
            if (error != nil) {
                self.task(handle).reject(error!)
            }
            else {
                if let services = peripheral.services {
                    self.task(handle).fulfill(services)
                }
                else {
                    self.task(handle).reject(BluenetError.NO_SERVICES)
                }
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let handle = peripheral.identifier
        
        if (self.task(handle).type == .GET_CHARACTERISTICS) {
            // we will allow silent errors here if we do not explicitly ask for characteristics
            if (error != nil) {
                self.task(handle).reject(error!)
            }
            else {
                if let characteristics = service.characteristics {
                    self.task(handle).fulfill(characteristics)
                }
                else {
                    self.task(handle).reject(BluenetError.NO_CHARACTERISTICS)
                }
            }
        }
    }
    
    /**
    * This is the reaction to read characteristic AND notifications!
    */
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let handle = peripheral.identifier
    
        // handle the case for failed bonding
        if (error != nil) {
            if (self.task(handle).type == .READ_CHARACTERISTIC) {
                self.task(handle).reject(error!)
            }
            return
        }
        
        
        // in case of notifications:
        let serviceId = characteristic.service!.uuid.uuidString
        let characteristicId = characteristic.uuid.uuidString
        let topicString = serviceId + "_" + characteristicId
        if (self.notificationBus(handle).hasListeners(topicString)) {
            if let data = characteristic.value {
                // notifications are a chopped up encrypted message. We leave decryption for the handling methods.
                self.notificationBus(handle).emit(topicString, data)
            }
        }
    
        
        if (self.task(handle).type == .READ_CHARACTERISTIC) {
            if (characteristic.value != nil) {
                let data = characteristic.value!
                if (self.connectionState(handle).isEncryptionEnabled()) {
                    do {
                        let decryptedData = try EncryptionHandler.decrypt(data, connectionState: self.connectionState(handle))
                        self.task(handle).fulfill(decryptedData.bytes)
                    }
                    catch let err {
                        self.task(handle).reject(err)
                    }
                }
                else {
                    self.task(handle).fulfill(data.bytes)
                }
            }
            else {
                self.task(handle).fulfill([UInt8]())
            }
        }
    }
    
    
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let handle = peripheral.identifier
        LOG.info("BLUENET_LIB: written to \(handle)")
        self.connectionState(handle).written()
        if (self.task(handle).type == .WRITE_CHARACTERISTIC) {
            if (error != nil) {
                self.task(handle).reject(error!)
            }
            else {
                self.task(handle).fulfill(())
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let handle = peripheral.identifier
        LOG.info("BLUENET_LIB: didUpdateNotificationStateFor for \(handle)")
        self.connectionState(handle).written()
        if (self.task(handle).type == .ENABLE_NOTIFICATIONS || self.task(handle).type == .DISABLE_NOTIFICATIONS) {
            if (error != nil) {
                self.task(handle).reject(error!)
            }
            else {
                self.task(handle).fulfill(())
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        peripheral.discoverServices(nil)
    }
    
    
    
    
}

