//
//  PromiseContainer.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 17/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

enum RequestType {
    case NONE
    case DISCONNECT
    case CANCEL_PENDING_CONNECTION
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
    case DATA
}


class promiseContainer {
    fileprivate var _fulfillVoidPromise             : (Void) -> Void                = {_ in }
    fileprivate var _fulfillIntPromise              : (Int) -> Void                 = {_ in }
    fileprivate var _fulfillServiceListPromise      : ([CBService]) -> Void         = {_ in }
    fileprivate var _fulfillCharacteristicListPromise : ([CBCharacteristic]) -> Void = {_ in }
    fileprivate var _fulfillCharacteristicPromise   : (CBCharacteristic) -> Void    = {_ in }
    fileprivate var _fulfillDataPromise             : ([UInt8]) -> Void    = {_ in }
    fileprivate var _rejectPromise                  : (Error) -> Void           = {_ in }
    var type = RequestType.NONE
    var promiseType = PromiseType.NONE
    var completed = false
    
    init(_ fulfill: @escaping (Void) -> Void, _ reject: @escaping (Error) -> Void, type: RequestType) {
        _fulfillVoidPromise = fulfill
        promiseType = .VOID
        initShared(reject, type)
    }
    
    init(_ fulfill: @escaping (Int) -> Void, _ reject: @escaping (Error) -> Void, type: RequestType) {
        _fulfillIntPromise = fulfill
        promiseType = .INT
        initShared(reject, type)
    }
    
    init(_ fulfill: @escaping ([CBService]) -> Void, _ reject: @escaping (Error) -> Void, type: RequestType) {
        _fulfillServiceListPromise = fulfill
        promiseType = .SERVICELIST
        initShared(reject, type)
    }
    
    init(_ fulfill: @escaping ([CBCharacteristic]) -> Void, _ reject: @escaping (Error) -> Void, type: RequestType) {
        _fulfillCharacteristicListPromise = fulfill
        promiseType = .CHARACTERISTICLIST
        initShared(reject, type)
    }
    
    init(_ fulfill: @escaping (CBCharacteristic) -> Void, _ reject: @escaping (Error) -> Void, type: RequestType) {
        _fulfillCharacteristicPromise = fulfill
        promiseType = .CHARACTERISTIC
        initShared(reject, type)
    }
    
    
    init(_ fulfill: @escaping ([UInt8]) -> Void, _ reject: @escaping (Error) -> Void, type: RequestType) {
        _fulfillDataPromise = fulfill
        promiseType = .DATA
        initShared(reject, type)
    }
    
    func initShared(_ reject: @escaping (Error) -> Void, _ type: RequestType) {
        _rejectPromise = reject
        self.type = type
    }
    
    func setDelayedFulfill(_ delayTimeInSeconds: Double) {
        if (promiseType == .VOID) {
            delay(delayTimeInSeconds, {_ in self.fulfill()})
        }
        else {
            _rejectPromise(BleError.CANNOT_SET_TIMEOUT_WITH_THIS_TYPE_OF_PROMISE)
        }
    }
    
    func setDelayedReject(_ delayTimeInSeconds: Double, errorOnReject: BleError) {
        delay(delayTimeInSeconds, {_ in self.reject(errorOnReject as! Error)})
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
    
    func fulfill(_ data: Void) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .VOID) {
                _fulfillVoidPromise(data)
            }
            else {
                _rejectPromise(BleError.WRONG_TYPE_OF_PROMISE)
            }
            clear()
        }
    }
    
    func fulfill(_ data: Int) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .INT) {
                _fulfillIntPromise(data)
            }
            else {
                _rejectPromise(BleError.WRONG_TYPE_OF_PROMISE)
            }
        }
        clear()
    }
    
    func fulfill(_ data: [CBService]) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .SERVICELIST) {
                _fulfillServiceListPromise(data)
            }
            else {
                _rejectPromise(BleError.WRONG_TYPE_OF_PROMISE)
            }
        }
        clear()
    }
    
    func fulfill(_ data: [CBCharacteristic]) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .CHARACTERISTICLIST) {
                _fulfillCharacteristicListPromise(data)
            }
            else {
                _rejectPromise(BleError.WRONG_TYPE_OF_PROMISE)
            }
        }
        clear()
    }
    
    func fulfill(_ data: CBCharacteristic) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .CHARACTERISTIC) {
                _fulfillCharacteristicPromise(data)
            }
            else {
                _rejectPromise(BleError.WRONG_TYPE_OF_PROMISE)
            }
        }
        clear()
    }
    
    func fulfill(_ data: [UInt8]) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .DATA) {
                _fulfillDataPromise(data)
            }
            else {
                _rejectPromise(BleError.WRONG_TYPE_OF_PROMISE)
            }
        }
        clear()
    }

    
    func reject(_ error: Error) {
        if (self.completed == false) {
            self.completed = true
            _rejectPromise(error)
        }
        clear()
    }
    
}
