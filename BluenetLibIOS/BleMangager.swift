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
    case CONNECTION_TIMEOUT
    case NOT_CONNECTED
    case NO_SERVICES
    case NO_CHARACTERISTICS
    case SERVICE_DOES_NOT_EXIST
    case CHARACTERISTIC_DOES_NOT_EXIST
    case WRONG_TYPE_OF_PROMISE
    case INVALID_UUID
    case NOT_INITIALIZED
}

enum RequestType {
    case NONE
    case DISCONNECT
    case CONNECT
    case GET_SERVICES
    case GET_CHARACTERISTICS
    case READ_CHARACTERISTIC
    case WRITE_CHARACTERISTIC
    case ENABLE_NOTIFICATIONS
    case DISABLE_NOTIFICATIONS
}

enum PromiseType {
    case NONE
    case VOID
    case INT
    case SERVICELIST
    case CHARACTERISTICLIST
    case CHARACTERISTIC
}




class promiseContainer {
    private var _fulfillVoidPromise             : (Void) -> Void                = {_ in }
    private var _fulfillIntPromise              : (Int) -> Void                 = {_ in }
    private var _fulfillServiceListPromise      : ([CBService]) -> Void         = {_ in }
    private var _fulfillCharacteristicListPromise : ([CBCharacteristic]) -> Void = {_ in }
    private var _fulfillCharacteristicPromise   : (CBCharacteristic) -> Void    = {_ in }
    private var _rejectPromise                  : (ErrorType) -> Void           = {_ in }
    var type = RequestType.NONE
    var promiseType = PromiseType.NONE
    
    init(_ fulfill: (Void) -> Void, _ reject: (ErrorType) -> Void, type: RequestType) {
        _fulfillVoidPromise = fulfill
        promiseType = .VOID
        initShared(reject, type)
    }

    init(_ fulfill: (Int) -> Void, _ reject: (ErrorType) -> Void, type: RequestType) {
        _fulfillIntPromise = fulfill
        promiseType = .INT
        initShared(reject, type)
    }
    
    init(_ fulfill: ([CBService]) -> Void, _ reject: (ErrorType) -> Void, type: RequestType) {
        _fulfillServiceListPromise = fulfill
        promiseType = .SERVICELIST
        initShared(reject, type)
    }
    
    init(_ fulfill: ([CBCharacteristic]) -> Void, _ reject: (ErrorType) -> Void, type: RequestType) {
        _fulfillCharacteristicListPromise = fulfill
        promiseType = .CHARACTERISTICLIST
        initShared(reject, type)
    }
    
    init(_ fulfill: (CBCharacteristic) -> Void, _ reject: (ErrorType) -> Void, type: RequestType) {
        _fulfillCharacteristicPromise = fulfill
        promiseType = .CHARACTERISTIC
        initShared(reject, type)
    }
    
    func initShared(reject: (ErrorType) -> Void, _ type: RequestType) {
        _rejectPromise = reject
        self.type = type
    }
    
    
    init() {
        self.clear()
    }
    
    
    func clear() {
        type = .NONE
        promiseType = .NONE
        _fulfillVoidPromise  = {_ in }
        _fulfillServiceListPromise = {_ in }
        _fulfillCharacteristicListPromise = {_ in }
        _fulfillCharacteristicPromise = {_ in }
        _rejectPromise = {_ in }
    }
    
    func fulfill(data: Void) {
        if (promiseType == .VOID) {
            _fulfillVoidPromise(data)
        }
        else {
            _rejectPromise(BleError.WRONG_TYPE_OF_PROMISE)
        }
        clear()
    }
    
    func fulfill(data: Int) {
        if (promiseType == .INT) {
            _fulfillIntPromise(data)
        }
        else {
            _rejectPromise(BleError.WRONG_TYPE_OF_PROMISE)
        }
        clear()
    }
    
    func fulfill(data: [CBService]) {
        if (promiseType == .SERVICELIST) {
            _fulfillServiceListPromise(data)
        }
        else {
            _rejectPromise(BleError.WRONG_TYPE_OF_PROMISE)
        }
        clear()
    }
    
    func fulfill(data: [CBCharacteristic]) {
        if (promiseType == .CHARACTERISTICLIST) {
            _fulfillCharacteristicListPromise(data)
        }
        else {
            _rejectPromise(BleError.WRONG_TYPE_OF_PROMISE)
        }
        clear()
    }
    
    func fulfill(data: CBCharacteristic) {
        if (promiseType == .CHARACTERISTIC) {
            _fulfillCharacteristicPromise(data)
        }
        else {
            _rejectPromise(BleError.WRONG_TYPE_OF_PROMISE)
        }
        clear()
    }
    
    func reject(error: ErrorType) {
        _rejectPromise(error)
        clear()
    }
    
}

public class Advertisement {
    public var uuid : String
    public var name : String
    public var rssi : NSNumber
    public var serviceData = [String: [NSNumber]]()
    public var serviceDataAvailable : Bool
    
    init(uuid: String, name: String?, rssi: NSNumber, serviceData: AnyObject?) {
        if (name != nil) {
            self.name = name!
        }
        else {
            self.name = ""
        }
        self.uuid = uuid
        self.rssi = rssi
        self.serviceDataAvailable = false
        
        if let castData = serviceData as? [CBUUID: NSData] {
            for (serviceCUUID, data) in castData {
                // convert data to uint8 array
                let uint8Arr = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(data.bytes), count: data.length))
                var numberArray = [NSNumber]()
                for uint8 in uint8Arr {
                    numberArray.append(NSNumber(unsignedChar: uint8))
                }
                self.serviceData[serviceCUUID.UUIDString] = numberArray
                self.serviceDataAvailable = true
            }
        }
    }
    
    public func getJSON() -> JSON {
        var dataDict = [String : AnyObject]()
        dataDict["id"] = self.uuid
        dataDict["name"] = self.name
        dataDict["rssi"] = self.rssi
        
        var dataJSON = JSON(dataDict)
        
        if (self.serviceDataAvailable) {
            dataJSON["serviceData"] = JSON(self.serviceData)
        }
        else {
            dataJSON["serviceData"] = []
        }

        return dataJSON
    }
    
}

public class BleManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager : CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    var connectingPeripheral: CBPeripheral?
    
    var BleState : CBCentralManagerState = .Unknown
    var pendingPromise : promiseContainer!
    var eventBus : EventBus!

    public init(eventBus: EventBus) {
        super.init();
        
        self.eventBus = eventBus;
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // initialize the pending promise containers
        pendingPromise = promiseContainer()
    }
    
    // MARK: API
    
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
    
    public func connect(uuid: String) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            if (self.BleState != .PoweredOn) {
                reject(BleError.NOT_INITIALIZED)
            }
            else {
                // cancel any connection attempt in progress.
                if (connectingPeripheral != nil) {
                    abortConnecting()
                }
                if (connectedPeripheral != nil) {
                    disconnect()
                        .then({ _ in return self._connect(uuid)})
                        .then({ _ in fulfill()})
                        .error(reject)
                }
                else {
                    self._connect(uuid)
                        .then({ _ in fulfill()})
                        .error(reject)
                }
            }
        };
    }
    
    func abortConnecting() {
        if (connectingPeripheral != nil) {
            centralManager.cancelPeripheralConnection(connectingPeripheral!)
            
            // if there was a connection in progress, cancel it with an error
            if (pendingPromise.type == .CONNECT) {
               pendingPromise.reject(BleError.CONNECTION_CANCELLED)
            }
        }
    }
    
    func _connect(uuid: String) -> Promise<Void> {
        let nsUuid = NSUUID(UUIDString: uuid)
        return Promise<Void> { fulfill, reject in
            if (nsUuid == nil) {
                reject(BleError.INVALID_UUID)
            }
            else {
                // get a peripheral from the known list (TODO: check what happens if it requests an unknown one)
                let peripheral = centralManager.retrievePeripheralsWithIdentifiers([nsUuid!])[0];
                connectingPeripheral = peripheral
                connectingPeripheral!.delegate = self
                
                // setup the pending promise for connection
                pendingPromise = promiseContainer(fulfill, reject, type: .CONNECT)
                
                // TODO: implement timeout.
                centralManager.connectPeripheral(connectingPeripheral!, options: nil)
            }
        }
    }
    
    public func disconnect() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            // only disconnect if we are actually connected!
            if (self.connectedPeripheral != nil) {
                let disconnectPromise = Promise<Void> { success, failure in
                    self.pendingPromise = promiseContainer(success, failure, type: .DISCONNECT)
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
    
    
    public func getServicesFromDevice() -> Promise<[CBService]> {
        return Promise<[CBService]> { fulfill, reject in
            if (connectedPeripheral != nil) {
                if let services = connectedPeripheral!.services {
                    fulfill(services)
                }
                else {
                    self.pendingPromise = promiseContainer(fulfill, reject, type: .GET_SERVICES)
                    
                    // the fulfil and reject are handled in the peripheral delegate
                    connectedPeripheral!.discoverServices(nil) // then return services
                }
            }
            else {
                reject(BleError.NOT_CONNECTED)
            }
        }
    }
    
    func getServiceFromList(list:[CBService], _ uuid: String) -> CBService? {
        for service in list {
            if (service.UUID.UUIDString == uuid) {
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
                        if let service = self.getServiceFromList(services, serviceId) {
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
        for characteristic in list {
            if (characteristic.UUID.UUIDString == uuid) {
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
                    .then({(services: [CBService]) -> Promise<[CBCharacteristic]> in // get characteristics
                        if let service = self.getServiceFromList(services, serviceId) {
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
    
    
    
    public func readCharacteristic(serviceId: String, characteristicId: String) -> Promise<CBCharacteristic> {
        return Promise<CBCharacteristic> { fulfill, reject in
            self.getChacteristic(serviceId, characteristicId)
                .then({characteristic in
                    self.pendingPromise = promiseContainer(fulfill, reject, type: .READ_CHARACTERISTIC)
                    
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
                    
                    // the fulfil and reject are handled in the peripheral delegate
                    self.connectedPeripheral!.writeValue(data, forCharacteristic: characteristic, type: type)
                })
                .error({(error: ErrorType) -> Void in
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
    
    public func stopScanning() {
        print ("stopping scan")
        centralManager.stopScan()
    }

    
    // MARK: CENTRAL MANAGER DELEGATE
    
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        self.BleState = central.state;
        switch (central.state) {
        case .Unsupported:
            print("BLE is Unsupported")
        case .Unauthorized:
            print("BLE is Unauthorized")
        case .Unknown:
            print("BLE is Unknown")
        case .Resetting:
            print("BLE is Resetting")
        case .PoweredOff:
            print("BLE is PoweredOff")
        case .PoweredOn:
            print("BLE is PoweredOn, start scanning")
            self.startScanning()
        }
    }
    
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        var emitData = Advertisement(
            uuid: peripheral.identifier.UUIDString,
            name: peripheral.name,
            rssi: RSSI,
            serviceData: advertisementData["kCBAdvDataServiceData"]
        );
        
        self.eventBus.emit("advertisementData",emitData)
    }
    
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        if (pendingPromise.type == .CONNECT) {
            print("connectiong")
            connectedPeripheral = peripheral
            connectingPeripheral = nil
            pendingPromise.fulfill()
        }
    }
    
    public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
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
        if (error != nil) {
            pendingPromise.reject(error!)
        }
        else {
            // if the pending promise is NOT for disconnect, a disconnection event is a rejection.
            if (pendingPromise.type != .DISCONNECT) {
                pendingPromise.reject(BleError.DISCONNECTED)
            }
            else {
                pendingPromise.fulfill()
            }
        }
        
    }
    
    public func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        print("WILL RESTORE STATE",dict);
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
        // in case of notifications:
        let serviceId = characteristic.service.UUID.UUIDString;
        let characteristicId = characteristic.UUID.UUIDString;
        if (self.eventBus.hasListeners(serviceId + "_" + characteristicId)) {
            if let data = characteristic.value {
                self.eventBus.emit(serviceId + "_" + characteristicId, data)
            }
        }
        
        if (pendingPromise.type == .READ_CHARACTERISTIC) {
            if (error != nil) {
                pendingPromise.reject(error!)
            }
            else {
                pendingPromise.fulfill(characteristic)
            }
        }
    }
    
    
    
    public func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
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

