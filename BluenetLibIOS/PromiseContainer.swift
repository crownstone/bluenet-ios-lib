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
    var completed = false
    
    
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
    
    func setFulfillOnTimeout(delayTimeInSeconds: Double) {
        if (promiseType == .VOID) {
            delay(delayTimeInSeconds, {_ in self.fulfill()})
        }
        else {
            _rejectPromise(BleError.CANNOT_SET_TIMEOUT_WITH_THIS_TYPE_OF_PROMISE)
        }
    }
    
    func setTimeout(delayTimeInSeconds: Double) {
        delay(delayTimeInSeconds, {_ in self.reject(BleError.TIMEOUT)})
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
    
    func fulfill(data: Int) {
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
    
    func fulfill(data: [CBService]) {
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
    
    func fulfill(data: [CBCharacteristic]) {
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
    
    func fulfill(data: CBCharacteristic) {
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
    
    func reject(error: ErrorType) {
        if (self.completed == false) {
            self.completed = true
            _rejectPromise(error)
        }
        clear()
    }
    
}