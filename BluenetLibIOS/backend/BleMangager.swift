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

}

struct timeoutDurations {
    static let disconnect              : Double = 3
    static let cancelPendingConnection : Double = 3
    static let connect                 : Double = 10
    static let getServices             : Double = 3
    static let getCharacteristics      : Double = 3
    static let readCharacteristic      : Double = 3
    static let writeCharacteristic     : Double = 4
    static let writeCharacteristicWithout : Double = 0.5
    static let enableNotifications     : Double = 2
    static let disableNotifications    : Double = 2
    static let waitForBond             : Double = 12
    static let waitForWrite            : Double = 0.35
    static let waitForReconnect        : Double = 2.0
    static let waitForRestart          : Double = 2
}



open class BleManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager : CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    var connectingPeripheral: CBPeripheral?
    
    var BleState : CBCentralManagerState = .unknown
    var pendingPromise : promiseContainer!
    var eventBus : EventBus!
    open var settings : BluenetSettings!

    public init(eventBus: EventBus) {
        super.init();
        
        self.settings = BluenetSettings()
        self.eventBus = eventBus
        self.centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true, CBCentralManagerOptionRestoreIdentifierKey: "BluenetIOS"])
        
        // initialize the pending promise containers
        pendingPromise = promiseContainer()
    }
    
    open func setSettings(_ settings: BluenetSettings) {
        self.settings = settings
    }
   
    
    // MARK: API
    /**
     * This method will fulfill when the bleManager is ready. It polls itself every 0.25 seconds. Never rejects.
     *
     */
    open func isReady() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            if (self.BleState != .poweredOn) {
                delay(0.50, {_ in _ = self.isReady().then{_ -> Void in fulfill()}})
            }
            else {
                fulfill()
            }
        }
    }
    
    open func waitToReconnect()  -> Promise<Void> {
        return Promise<Void> { fulfill, reject in delay(timeoutDurations.waitForReconnect, fulfill) }
    }
    
    open func waitForRestart()  -> Promise<Void> {
        return Promise<Void> { fulfill, reject in delay(timeoutDurations.waitForRestart, fulfill) }
    }
    
    // this delay is set up for calls that need to write to storage.
    open func waitToWrite(_ iteration: UInt8?) -> Promise<Void> {
        if (iteration != nil) {
            if (iteration! > 0) {
                print("------ BLUENET_LIB: Could not verify immediatly, waiting longer between steps...")
                return Promise<Void> { fulfill, reject in delay(2 * timeoutDurations.waitForWrite, fulfill) }
            }
        }
        return Promise<Void> { fulfill, reject in delay(timeoutDurations.waitForWrite, fulfill) }
    }

    
    /**
     * Connect to a ble device. The uuid is the Apple UUID which differs between phones for a single device
     *
     */
    open func connect(_ uuid: String) -> Promise<Void> {
        print ("------ BLUENET_LIB: starting to connect")
        return Promise<Void> { fulfill, reject in
            if (self.BleState != .poweredOn) {
                reject(BleError.NOT_INITIALIZED)
            }
            else {
                // start the connection
                if (connectedPeripheral != nil) {
                    if (connectedPeripheral!.identifier.uuidString == uuid) {
                        print ("------ BLUENET_LIB: Already connected to this peripheral")
                        fulfill();
                    }
                    else {
                        print ("------ BLUENET_LIB: Something is connected")
                        disconnect()
                            .then{ _ in self._connect(uuid)}
                            .then{ _ in fulfill()}
                            .catch{ err in reject(err)}
                    }
                }
                // cancel any connection attempt in progress.
                else if (connectingPeripheral != nil) {
                    print ("------ BLUENET_LIB: connection attempt in progress")
                    abortConnecting()
                        .then{ _ in return self._connect(uuid)}
                        .then{ _ in fulfill()}
                        .catch{ err in reject(err)}
                }
                else {
                    print ("------ BLUENET_LIB: connecting...")
                    self._connect(uuid)
                        .then{ _ in fulfill()}
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
            print ("------ BLUENET_LIB: starting to abort pending connection request")
            if (connectingPeripheral != nil) {
                print ("------ BLUENET_LIB: pending connection detected")
                // if there was a connection in progress, cancel it with an error
                if (pendingPromise.type == .CONNECT) {
                    print ("------ BLUENET_LIB: rejecting the connection promise")
                    pendingPromise.reject(BleError.CONNECTION_CANCELLED)
                }
                
                print ("------ BLUENET_LIB: Waiting to cancel connection....")
                pendingPromise = promiseContainer(fulfill, reject, type: .CANCEL_PENDING_CONNECTION)
                pendingPromise.setDelayedReject(timeoutDurations.cancelPendingConnection, errorOnReject: .CANCEL_PENDING_CONNECTION_TIMEOUT)
                
                centralManager.cancelPeripheralConnection(connectingPeripheral!)
                
                // we set it to nil here regardless if the connection abortion fails or not.
                connectingPeripheral = nil
            }
            else {
                fulfill()
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
                let peripherals = centralManager.retrievePeripherals(withIdentifiers: [nsUuid!]);
                if (peripherals.count == 0) {
                    reject(BleError.CAN_NOT_CONNECT_TO_UUID)
                }
                else {
                    let peripheral = peripherals[0]
                    connectingPeripheral = peripheral
                    connectingPeripheral!.delegate = self
                    
                    // setup the pending promise for connection
                    pendingPromise = promiseContainer(fulfill, reject, type: .CONNECT)
                    pendingPromise.setDelayedReject(timeoutDurations.connect, errorOnReject: .CONNECT_TIMEOUT)
                    
                    centralManager.connect(connectingPeripheral!, options: nil)

                }
            }
        }
    }
    
    /**
     *  Disconnect from the connected BLE device
     *
     */
    open func disconnect() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            // cancel any pending connections
            if (self.connectingPeripheral != nil) {
                print ("------ BLUENET_LIB: disconnecting from connecting peripheral")
                abortConnecting()
                    .then{ _ in return self._disconnect() }
                    .then{_ -> Void in fulfill()}
                    .catch{err in reject(err)}
            }
            else {
                self._disconnect().then{_ -> Void in fulfill()}.catch{err in reject(err)}
            }
        }
    }
    
    func _disconnect() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            // only disconnect if we are actually connected!
            if (self.connectedPeripheral != nil) {
                print ("------ BLUENET_LIB: disconnecting from connected peripheral")
                let disconnectPromise = Promise<Void> { success, failure in
                    self.pendingPromise = promiseContainer(success, failure, type: .DISCONNECT)
                    self.pendingPromise.setDelayedReject(timeoutDurations.disconnect, errorOnReject: .DISCONNECT_TIMEOUT)
                    self.centralManager.cancelPeripheralConnection(connectedPeripheral!)
                }
                // we clean up (self.connectedPeripheral = nil) inside the disconnect() method, thereby needing this inner promise
                disconnectPromise.then { _ -> Void in
                    // make sure the connected peripheral is set to nil so we know nothing is connected
                    self.connectedPeripheral = nil
                    fulfill()
                }
                .catch { err in reject(err) }
            }
            else {
                fulfill()
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
                    self.pendingPromise = promiseContainer(fulfill, reject, type: .GET_SERVICES)
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
                    self.pendingPromise = promiseContainer(fulfill, reject, type: .GET_CHARACTERISTICS)
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
                    
                    self.pendingPromise = promiseContainer(fulfill, reject, type: .READ_CHARACTERISTIC)
                    self.pendingPromise.setDelayedReject(timeoutDurations.readCharacteristic, errorOnReject: .READ_CHARACTERISTIC_TIMEOUT)
                    
                    // the fulfil and reject are handled in the peripheral delegate
                    self.connectedPeripheral!.readValue(for: characteristic)
                }
                .catch{err in reject(err)}
        }
    }
    
    open func writeToCharacteristic(_ serviceId: String, characteristicId: String, data: Data, type: CBCharacteristicWriteType) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            self.getChacteristic(serviceId, characteristicId)
                .then{characteristic -> Void in
                    self.pendingPromise = promiseContainer(fulfill, reject, type: .WRITE_CHARACTERISTIC)
                    
                    if (type == .withResponse) {
                        self.pendingPromise.setDelayedReject(timeoutDurations.writeCharacteristic, errorOnReject: .WRITE_CHARACTERISTIC_TIMEOUT)
                    }
                    else {
                        // if we write without notification, the delegate will not be invoked.
                        self.pendingPromise.setDelayedFulfill(timeoutDurations.writeCharacteristicWithout)
                    }
                    
                    // the fulfil and reject are handled in the peripheral delegate
                    if (self.settings.isEncryptionEnabled()) {
                        do {
                            let encryptedData = try EncryptionHandler.encrypt(data, settings: self.settings)
                            self.connectedPeripheral!.writeValue(encryptedData, for: characteristic, type: type)
                        }
                        catch let err {
                            self.pendingPromise.reject(err)
                        }
                    }
                    else {
                        print ("------ BLUENET_LIB: writing \(data) ")
                        self.connectedPeripheral!.writeValue(data, for: characteristic, type: type)
                    }

                }
                .catch{(error: Error) -> Void in
                    print ("~~~~~~ BLUENET_LIB: FAILED writing to characteristic \(error)")
                    reject(error)
                }
        }
    }
    
    open func enableNotifications(_ serviceId: String, characteristicId: String, callback: @escaping eventCallback) -> Promise<voidPromiseCallback> {
        var unsubscribeCallback : voidCallback? = nil
        return Promise<voidPromiseCallback> { fulfill, reject in
            // if there is already a listener on this topic, we assume notifications are already enabled. We just add another listener
            if (self.eventBus.hasListeners(serviceId + "_" + characteristicId)) {
                unsubscribeCallback = self.eventBus.on(serviceId + "_" + characteristicId, callback)
                
                // create the cleanup callback and return it.
                let cleanupCallback : voidPromiseCallback = { _ in
                    return self.disableNotifications(serviceId, characteristicId: characteristicId, unsubscribeCallback: unsubscribeCallback!)
                }
                fulfill(cleanupCallback)
            }
            else {
                // we first get the characteristic from the device
                self.getChacteristic(serviceId, characteristicId)
                    // then we subscribe to the feed before we know it works to miss no data.
                    .then{(characteristic: CBCharacteristic) -> Promise<Void> in
                        unsubscribeCallback = self.eventBus.on(characteristic.service.uuid.uuidString + "_" + characteristic.uuid.uuidString, callback)
                        
                        // we now tell the device to notify us.
                        return Promise<Void> { success, failure in
                            // the success and failure are handled in the peripheral delegate
                            self.pendingPromise = promiseContainer(success, failure, type: .ENABLE_NOTIFICATIONS)
                            self.pendingPromise.setDelayedReject(timeoutDurations.enableNotifications, errorOnReject: .ENABLE_NOTIFICATIONS_TIMEOUT)
                            self.connectedPeripheral!.setNotifyValue(true, for: characteristic)
                        }
                    }
                    .then{_ -> Void in
                        let cleanupCallback : voidPromiseCallback = { _ in return self.disableNotifications(serviceId, characteristicId: characteristicId, unsubscribeCallback: unsubscribeCallback!) }
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
            if (self.eventBus.hasListeners(serviceId + "_" + characteristicId)) {
                fulfill()
            }
            else {
                // if there are no more people listening, we tell the device to stop the notifications.
                self.getChacteristic(serviceId, characteristicId)
                    .then{characteristic -> Void in
                        self.pendingPromise = promiseContainer(fulfill, reject, type: .DISABLE_NOTIFICATIONS)
                        self.pendingPromise.setDelayedReject(timeoutDurations.disableNotifications, errorOnReject: .DISABLE_NOTIFICATIONS_TIMEOUT)
                        
                        // the fulfil and reject are handled in the peripheral delegate
                        self.connectedPeripheral!.setNotifyValue(false, for: characteristic)
                    }
                    .catch{(error: Error) -> Void in
                        reject(error)
                    }
            }
        }
    }
    
    // MARK: scanning
    
    open func startScanning() {
        print ("------ BLUENET_LIB: start scanning everything")
        //        let generalService = CBUUID(string: "f5f90000-f5f9-11e4-aa15-123b93f75cba")
        //let generalService = CBUUID(string: "5432")
        // centralManager.scanForPeripheralsWithServices([generalService], options:nil)//, options:[CBCentralManagerScanOptionAllowDuplicatesKey:false])
        centralManager.scanForPeripherals(withServices: nil, options:[CBCentralManagerScanOptionAllowDuplicatesKey:true])
    }
    
    open func startScanningForService(_ serviceUUID: String, uniqueOnly: Bool = false) {
        print ("------ BLUENET_LIB: start scanning for services \(serviceUUID)")
        let service = CBUUID(string: serviceUUID)
        centralManager.scanForPeripherals(withServices: [service], options:[CBCentralManagerScanOptionAllowDuplicatesKey: uniqueOnly])
    }
    
    open func startScanningForServices(_ serviceUUIDs: [String], uniqueOnly: Bool = false) {
        print ("------ BLUENET_LIB: start scanning for multiple services \(serviceUUIDs)")
        var services = [CBUUID]()
        for service in serviceUUIDs {
            services.append(CBUUID(string: service))
        }
        
        centralManager.scanForPeripherals(withServices: services, options:[CBCentralManagerScanOptionAllowDuplicatesKey: uniqueOnly])
    }
    
    open func stopScanning() {
        print ("------ BLUENET_LIB: stopping scan")
        centralManager.stopScan()
    }

    
    // MARK: CENTRAL MANAGER DELEGATE
    
    open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if #available(iOS 10.0, *) {
            switch central.state{
            case CBManagerState.unauthorized:
                self.BleState = .unauthorized
                self.eventBus.emit("bleStatus", "unauthorized");
                print("------ BLUENET_LIB: This app is not authorised to use Bluetooth low energy")
            case CBManagerState.poweredOff:
                self.BleState = .poweredOff
                self.eventBus.emit("bleStatus", "poweredOff");
                print("------ BLUENET_LIB: Bluetooth is currently powered off.")
            case CBManagerState.poweredOn:
                self.BleState = .poweredOn
                self.eventBus.emit("bleStatus", "poweredOn");
                print("------ BLUENET_LIB: Bluetooth is currently powered on and available to use.")
            default:
                self.eventBus.emit("bleStatus", "unknown");
                break
            }
        } else {
            // Fallback on earlier versions
            switch central.state.rawValue {
            case 3: // CBCentralManagerState.unauthorized :
                self.BleState = .unauthorized
                self.eventBus.emit("bleStatus", "unauthorized");
                print("------ BLUENET_LIB: This app is not authorised to use Bluetooth low energy")
            case 4: // CBCentralManagerState.poweredOff:
                self.BleState = .poweredOff
                self.eventBus.emit("bleStatus", "poweredOff");
                print("------ BLUENET_LIB: Bluetooth is currently powered off.")
            case 5: //CBCentralManagerState.poweredOn:
                self.BleState = .poweredOn
                self.eventBus.emit("bleStatus", "poweredOn");
                print("------ BLUENET_LIB: Bluetooth is currently powered on and available to use.")
            default:
                self.eventBus.emit("bleStatus", "unknown");
                break
            }
        }
    }
    
    open func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let emitData = Advertisement(
            handle: peripheral.identifier.uuidString,
            name: peripheral.name,
            rssi: RSSI,
            serviceData: advertisementData["kCBAdvDataServiceData"],
            serviceUUID: advertisementData["kCBAdvDataServiceUUIDs"]
        );

        if (self.settings.isEncryptionEnabled() && emitData.isSetupPackage() == false && settings.guestKey != nil) {
            emitData.decrypt(settings.guestKey!)
            self.eventBus.emit("advertisementData",emitData)
        }
        else {
            self.eventBus.emit("advertisementData",emitData)
        }
    }
    
    open func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("------ BLUENET_LIB: in didConnectPeripheral")
        if (pendingPromise.type == .CONNECT) {
            print("------ BLUENET_LIB: connected")
            connectedPeripheral = peripheral
            connectingPeripheral = nil
            pendingPromise.fulfill()
        }
    }
    
    open func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("------ BLUENET_LIB: in didFailToConnectPeripheral")
        if (error != nil) {
            pendingPromise.reject(error!)
        }
        else {
            if (pendingPromise.type == .CONNECT) {
                pendingPromise.reject(error!)
            }
        }
    }
    
    open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // since we disconnected, we must set the connected peripherals to nil.
        self.connectingPeripheral = nil;
        self.connectedPeripheral = nil;
        self.settings.invalidateSessionNonce()
        
        print("------ BLUENET_LIB: in didDisconnectPeripheral")
        if (pendingPromise.type == .CANCEL_PENDING_CONNECTION) {
            pendingPromise.fulfill()
        }
        else {
            if (error != nil) {
                print("------ BLUENET_LIB: Disconnected with error \(error!)")
                pendingPromise.reject(error!)
            }
            else {
                print("------ BLUENET_LIB: Disconnected succesfully")
                // if the pending promise is NOT for disconnect, a disconnection event is a rejection.
                if (pendingPromise.type != .DISCONNECT) {
                    pendingPromise.reject(BleError.DISCONNECTED)
                }
                else {
                    pendingPromise.fulfill()
                }
            }
        }
    }
    
    open func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("------ BLUENET_LIB: WILL RESTORE STATE",dict);
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
        if (self.eventBus.hasListeners(topicString)) {
            if let data = characteristic.value {
                // notifications are a chopped up encrypted message. We leave decryption for the handling methods.
                self.eventBus.emit(topicString, data)
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
        print("------ BLUENET_LIB: written")
        if (pendingPromise.type == .WRITE_CHARACTERISTIC) {
            if (error != nil) {
                pendingPromise.reject(error!)
            }
            else {
                pendingPromise.fulfill()
            }
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if (pendingPromise.type == .ENABLE_NOTIFICATIONS || pendingPromise.type == .DISABLE_NOTIFICATIONS) {
            if (error != nil) {
                pendingPromise.reject(error!)
            }
            else {
                pendingPromise.fulfill()
            }
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        peripheral.discoverServices(nil)
    }
    
    
    
    
}

