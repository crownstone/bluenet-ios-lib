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

public enum BleError : ErrorType {
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
    static let waitForWrite            : Double = 0.5
    static let waitForReconnect        : Double = 0.5
}



public class BleManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager : CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    var connectingPeripheral: CBPeripheral?
    
    var BleState : CBCentralManagerState = .Unknown
    var pendingPromise : promiseContainer!
    var eventBus : EventBus!
    public var settings : BluenetSettings!

    public init(eventBus: EventBus) {
        super.init();
        
        self.settings = BluenetSettings()
        self.eventBus = eventBus
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // initialize the pending promise containers
        pendingPromise = promiseContainer()
    }
    
    public func setSettings(settings: BluenetSettings) {
        self.settings = settings
    }
   
    
    // MARK: API
    /**
     * This method will fulfill when the bleManager is ready. It polls itself every 0.25 seconds. Never rejects.
     *
     */
    public func isReady() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            if (self.BleState != .PoweredOn) {
                delay(0.25, {_ in self.isReady().then({_ in fulfill()})})
            }
            else {
                fulfill()
            }
        }
    }
    
    public func waitToReconnect()  -> Promise<Void> {
        return Promise<Void> { fulfill, reject in delay(timeoutDurations.waitForReconnect, fulfill) }
    }
    
    // this delay is set up for calls that need to write to storage.
    public func waitToWrite() -> Promise<Void> {
        print ("waiting for \(timeoutDurations.waitForWrite) second")
        return Promise<Void> { fulfill, reject in delay(timeoutDurations.waitForWrite, fulfill) }
    }
    
    /**
     * Connect to a ble device. The uuid is the Apple UUID which differs between phones for a single device
     *
     */
    public func connect(uuid: String) -> Promise<Void> {
        print ("------ BLUENET_LIB: starting to connect")
        return Promise<Void> { fulfill, reject in
            if (self.BleState != .PoweredOn) {
                reject(BleError.NOT_INITIALIZED)
            }
            else {
                // start the connection
                if (connectedPeripheral != nil) {
                    print ("------ BLUENET_LIB: Something is connected")
                    disconnect()
                        .then({ _ in return self._connect(uuid)})
                        .then({ _ in fulfill()})
                        .error(reject)
                }
                // cancel any connection attempt in progress.
                else if (connectingPeripheral != nil) {
                    print ("------ BLUENET_LIB: connection attempt in progress")
                    abortConnecting()
                        .then({ _ in return self._connect(uuid)})
                        .then({ _ in fulfill()})
                        .error(reject)
                }
                else {
                    print ("------ BLUENET_LIB: connecting...")
                    self._connect(uuid)
                        .then({ _ in fulfill()})
                        .error(reject)
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
    func _connect(uuid: String) -> Promise<Void> {
        let nsUuid = NSUUID(UUIDString: uuid)
        return Promise<Void> { fulfill, reject in
            if (nsUuid == nil) {
                reject(BleError.INVALID_UUID)
            }
            else {
                // get a peripheral from the known list (TODO: check what happens if it requests an unknown one)
                let peripherals = centralManager.retrievePeripheralsWithIdentifiers([nsUuid!]);
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
                    
                    
                    centralManager.connectPeripheral(connectingPeripheral!, options: nil)

                }
            }
        }
    }
    
    /**
     *  Disconnect from the connected BLE device
     *
     */
    public func disconnect() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            // cancel any pending connections
            if (self.connectingPeripheral != nil) {
                print ("------ BLUENET_LIB: disconnecting from connecting peripheral")
                abortConnecting()
                    .then({ _ in return self._disconnect() })
                    .then(fulfill)
                    .error(reject)
            }
            else {
                self._disconnect().then(fulfill).error(reject)
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
                disconnectPromise.then({ _ in
                    // make sure the connected peripheral is set to nil so we know nothing is connected
                    self.connectedPeripheral = nil
                    fulfill()
                }).error(reject)
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
    public func getServicesFromDevice() -> Promise<[CBService]> {
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
    
    func _getServiceFromList(list:[CBService], _ uuid: String) -> CBService? {
        let matchString = uuid.uppercaseString
        for service in list {
            if (service.UUID.UUIDString == matchString) {
                return service
            }
        }
        return nil;
    }
    
    public func getCharacteristicsFromDevice(serviceId: String) -> Promise<[CBCharacteristic]> {
        return Promise<[CBCharacteristic]> { fulfill, reject in
            // if we are not connected, exit
            if (connectedPeripheral != nil) {
                // get all services from connected device (is cached if we already know it)
                self.getServicesFromDevice()
                    // then get all characteristics from connected device (is cached if we already know it)
                    .then({(services: [CBService]) -> Promise<[CBCharacteristic]> in // get characteristics
                        if let service = self._getServiceFromList(services, serviceId) {
                            return self.getCharacteristicsFromDevice(service)
                        }
                        else {
                            throw BleError.SERVICE_DOES_NOT_EXIST
                        }
                    })
                    // then get the characteristic we need if it is in the list.
                    .then({(characteristics: [CBCharacteristic]) -> Void in
                        fulfill(characteristics);
                    })
                    .error({(error: ErrorType) -> Void in
                        reject(error)
                    })
            }
            else {
                reject(BleError.NOT_CONNECTED)
            }
        }
    }
    
    func getCharacteristicsFromDevice(service: CBService) -> Promise<[CBCharacteristic]> {
        return Promise<[CBCharacteristic]> { fulfill, reject in
            if (connectedPeripheral != nil) {
                if let characteristics = service.characteristics {
                    fulfill(characteristics)
                }
                else {
                    self.pendingPromise = promiseContainer(fulfill, reject, type: .GET_CHARACTERISTICS)
                    self.pendingPromise.setDelayedReject(timeoutDurations.getCharacteristics, errorOnReject: .GET_CHARACTERISTICS_TIMEOUT)

                    // the fulfil and reject are handled in the peripheral delegate
                    connectedPeripheral!.discoverCharacteristics(nil, forService: service)// then return services
                }
            }
            else {
                reject(BleError.NOT_CONNECTED)
            }
        }
    }
    
    func getCharacteristicFromList(list: [CBCharacteristic], _ uuid: String) -> CBCharacteristic? {
        let matchString = uuid.uppercaseString
        for characteristic in list {
            if (characteristic.UUID.UUIDString == matchString) {
                return characteristic
            }
        }
        return nil;
    }
    
    func getChacteristic(serviceId: String, _ characteristicId: String) -> Promise<CBCharacteristic> {
        return Promise<CBCharacteristic> { fulfill, reject in
            // if we are not connected, exit
            if (connectedPeripheral != nil) {
                // get all services from connected device (is cached if we already know it)
                self.getServicesFromDevice()
                    // then get all characteristics from connected device (is cached if we already know it)
                    .then({(services: [CBService]) -> Promise<[CBCharacteristic]> in
                        if let service = self._getServiceFromList(services, serviceId) {
                            return self.getCharacteristicsFromDevice(service)
                        }
                        else {
                            throw BleError.SERVICE_DOES_NOT_EXIST
                        }
                    })
                    // then get the characteristic we need if it is in the list.
                    .then({(characteristics: [CBCharacteristic]) -> Void in
                        if let characteristic = self.getCharacteristicFromList(characteristics, characteristicId) {
                            fulfill(characteristic)
                        }
                        else {
                            throw BleError.CHARACTERISTIC_DOES_NOT_EXIST
                        }
                    })
                    .error({(error: ErrorType) -> Void in
                        reject(error)
                    })
            }
            else {
                reject(BleError.NOT_CONNECTED)
            }
        }
    }
    
    public func readCharacteristicWithoutEncryption(service: String, characteristic: String) -> Promise<[UInt8]> {
        return Promise<[UInt8]> { fulfill, reject in
            self.settings.disableEncryptionTemporarily()
            self.readCharacteristic(service, characteristicId: characteristic)
                .then({data -> Void in
                    self.settings.restoreEncryption()
                    fulfill(data)
                })
                .error({(error: ErrorType) -> Void in
                    self.settings.restoreEncryption()
                    reject(error)
                })
        }
    }
    
    public func readCharacteristic(serviceId: String, characteristicId: String) -> Promise<[UInt8]> {
        return Promise<[UInt8]> { fulfill, reject in
            self.getChacteristic(serviceId, characteristicId)
                .then({characteristic in
                    
                    self.pendingPromise = promiseContainer(fulfill, reject, type: .READ_CHARACTERISTIC)
                    self.pendingPromise.setDelayedReject(timeoutDurations.readCharacteristic, errorOnReject: .READ_CHARACTERISTIC_TIMEOUT)
                    
                    // the fulfil and reject are handled in the peripheral delegate
                    self.connectedPeripheral!.readValueForCharacteristic(characteristic)
                })
                .error({(error: ErrorType) -> Void in
                    reject(error)
                })
        }
    }
    
    public func writeToCharacteristic(serviceId: String, characteristicId: String, data: NSData, type: CBCharacteristicWriteType) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            self.getChacteristic(serviceId, characteristicId)
                .then({characteristic in
                    self.pendingPromise = promiseContainer(fulfill, reject, type: .WRITE_CHARACTERISTIC)
                    
                    if (type == .WithResponse) {
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
                            self.connectedPeripheral!.writeValue(encryptedData, forCharacteristic: characteristic, type: type)
                        }
                        catch let err {
                            self.pendingPromise.reject(err)
                        }
                    }
                    else {
                        print ("------ BLUENET_LIB: writing \(data) ")
                        self.connectedPeripheral!.writeValue(data, forCharacteristic: characteristic, type: type)
                    }

                })
                .error({(error: ErrorType) -> Void in
                    print ("~~~~~~ BLUENET_LIB: FAILED writing to characteristic \(error)")
                    reject(error)
                })
        }
    }
    
    public func enableNotifications(serviceId: String, characteristicId: String, callback: (AnyObject) -> Void) -> Promise<Int> {
        var subscriptionId : Int? = nil;
        return Promise<Int> { fulfill, reject in
            // we first get the characteristic from the device
            self.getChacteristic(serviceId, characteristicId)
                // then we subscribe to the feed before we know it works to miss no data.
                .then({(characteristic: CBCharacteristic) -> Promise<Void> in
                    subscriptionId = self.eventBus.on(serviceId + "_" + characteristicId, callback)
                    
                    // we now tell the device to notify us.
                    return Promise<Void> { success, failure in
                        // the success and failure are handled in the peripheral delegate
                        self.pendingPromise = promiseContainer(success, failure, type: .ENABLE_NOTIFICATIONS)
                        self.pendingPromise.setDelayedReject(timeoutDurations.enableNotifications, errorOnReject: .ENABLE_NOTIFICATIONS_TIMEOUT)
                        self.connectedPeripheral!.setNotifyValue(true, forCharacteristic: characteristic)
                    }
                })
                .then({_ in fulfill(subscriptionId!)})
                .error({(error: ErrorType) -> Void in
                    // if something went wrong, we make sure the callback will not be fired.
                    if (subscriptionId != nil) {
                        self.eventBus.off(subscriptionId!)
                    }
                    reject(error)
                })
        }
    }
    
    public func disableNotifications(serviceId: String, characteristicId: String, callbackId: Int) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            // remove the callback
            self.eventBus.off(callbackId)
            
            // if there are still other callbacks listening, we're done!
            if (self.eventBus.hasListeners(serviceId + "_" + characteristicId)) {
                fulfill()
            }
            else {
                // if there are no more people listening, we tell the device to stop the notifications.
                self.getChacteristic(serviceId, characteristicId)
                    .then({characteristic in
                        self.pendingPromise = promiseContainer(fulfill, reject, type: .DISABLE_NOTIFICATIONS)
                        self.pendingPromise.setDelayedReject(timeoutDurations.disableNotifications, errorOnReject: .DISABLE_NOTIFICATIONS_TIMEOUT)
                        
                        // the fulfil and reject are handled in the peripheral delegate
                        self.connectedPeripheral!.setNotifyValue(false, forCharacteristic: characteristic)
                    })
                    .error({(error: ErrorType) -> Void in
                        reject(error)
                    })
            }
        }
    }
    
    // MARK: scanning
    
    public func startScanning() {
        //        let generalService = CBUUID(string: "f5f90000-f5f9-11e4-aa15-123b93f75cba")
        //let generalService = CBUUID(string: "5432")
        // centralManager.scanForPeripheralsWithServices([generalService], options:nil)//, options:[CBCentralManagerScanOptionAllowDuplicatesKey:false])
        centralManager.scanForPeripheralsWithServices(nil, options:[CBCentralManagerScanOptionAllowDuplicatesKey:true])
    }
    
    public func startScanningForService(serviceUUID: String) {
        let service = CBUUID(string: serviceUUID)
        centralManager.scanForPeripheralsWithServices([service], options:[CBCentralManagerScanOptionAllowDuplicatesKey:true])
    }
    
    public func stopScanning() {
        print ("------ BLUENET_LIB: stopping scan")
        centralManager.stopScan()
    }

    
    // MARK: CENTRAL MANAGER DELEGATE
    
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        self.BleState = central.state;
        switch (central.state) {
        case .Unsupported:
            print("------ BLUENET_LIB: BLE is Unsupported")
        case .Unauthorized:
            print("------ BLUENET_LIB: BLE is Unauthorized")
        case .Unknown:
            print("------ BLUENET_LIB: BLE is Unknown")
        case .Resetting:
            print("------ BLUENET_LIB: BLE is Resetting")
        case .PoweredOff:
            print("------ BLUENET_LIB: BLE is PoweredOff")
        case .PoweredOn:
            print("------ BLUENET_LIB: BLE is PoweredOn, start scanning")
            //self.startScanning()
        }
    }
    
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        let emitData = Advertisement(
            uuid: peripheral.identifier.UUIDString,
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
    
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("------ BLUENET_LIB: in didConnectPeripheral")
        if (pendingPromise.type == .CONNECT) {
            print("------ BLUENET_LIB: connected")
            connectedPeripheral = peripheral
            connectingPeripheral = nil
            pendingPromise.fulfill()
        }
    }
    
    public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
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
    
    public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
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
    
    public func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        print("------ BLUENET_LIB: WILL RESTORE STATE",dict);
    }

    
    // MARK: peripheral delegate
    
    public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
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
    
    public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
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
    public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        // handle the case for failed bonding
        if (error != nil) {
            if (pendingPromise.type == .READ_CHARACTERISTIC) {
                pendingPromise.reject(error!)
            }
            return
        }
        
        // in case of notifications:
        let serviceId = characteristic.service.UUID.UUIDString;
        let characteristicId = characteristic.UUID.UUIDString;
        if (self.eventBus.hasListeners(serviceId + "_" + characteristicId)) {
            if let data = characteristic.value {
                if (self.settings.isEncryptionEnabled()) {
                    // TODO: decrypt
                    self.eventBus.emit(serviceId + "_" + characteristicId, data)
                }
                else {
                    self.eventBus.emit(serviceId + "_" + characteristicId, data)
                }
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
                            print("incoming \(data.arrayOfBytes())")
                            let decryptedData = try EncryptionHandler.decrypt(data, settings: self.settings)
                            pendingPromise.fulfill(decryptedData.arrayOfBytes())
                        }
                        catch let err {
                            pendingPromise.reject(err)
                        }
                    }
                    else {
                        pendingPromise.fulfill(data.arrayOfBytes())
                    }
                }
                else {
                    pendingPromise.fulfill([UInt8]())
                }
            }
        }
    }
    
    
    
    public func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
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
    
    public func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if (pendingPromise.type == .ENABLE_NOTIFICATIONS || pendingPromise.type == .DISABLE_NOTIFICATIONS) {
            if (error != nil) {
                pendingPromise.reject(error!)
            }
            else {
                pendingPromise.fulfill()
            }
        }
    }
    
    public func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        peripheral.discoverServices(nil)
    }
    
    
    
    
}

