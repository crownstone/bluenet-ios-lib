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
import CryptoSwift

enum RequestType {
    case NONE
    case DISCONNECT
    case ERROR_DISCONNECT
    case AWAIT_DISCONNECT
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


class PromiseContainer {
    var handle : String?
     
    fileprivate var _fulfillVoidPromise             : (Void) -> ()                   = {_ in }
    fileprivate var _fulfillIntPromise              : (Int) -> Void                  = {_ in }
    fileprivate var _fulfillServiceListPromise      : ([CBService]) -> Void          = {_ in }
    fileprivate var _fulfillCharacteristicListPromise : ([CBCharacteristic]) -> Void = {_ in }
    fileprivate var _fulfillCharacteristicPromise   : (CBCharacteristic) -> Void     = {_ in }
    fileprivate var _fulfillDataPromise             : ([UInt8]) -> Void              = {_ in }
    fileprivate var _rejectPromise                  : (Error) -> Void                = {_ in }
    fileprivate var rejectId : String = ""
    
    var type = RequestType.NONE
    var promiseType = PromiseType.NONE
    var completed = false
    var loadedPromise = false
    
    /**
        Handle is only used for logging.
     */
    init(_ handle: String) {
        self.handle = handle
        self._clear()
    }
    
    
    func load(_ fulfill: @escaping (Void) -> (), _ reject: @escaping (Error) -> Void, type: RequestType) {
        _cancelAnyPreviousPromise(newPromiseType: type)
        _fulfillVoidPromise = fulfill
        promiseType = .VOID
        initShared(reject, type)
    }
    
    func load(_ fulfill: @escaping (Int) -> Void, _ reject: @escaping (Error) -> Void, type: RequestType) {
        _cancelAnyPreviousPromise(newPromiseType: type)
        _fulfillIntPromise = fulfill
        promiseType = .INT
        initShared(reject, type)
    }
    
    func load(_ fulfill: @escaping ([CBService]) -> Void, _ reject: @escaping (Error) -> Void, type: RequestType) {
        _cancelAnyPreviousPromise(newPromiseType: type)
        _fulfillServiceListPromise = fulfill
        promiseType = .SERVICELIST
        initShared(reject, type)
    }
    
    func load(_ fulfill: @escaping ([CBCharacteristic]) -> Void, _ reject: @escaping (Error) -> Void, type: RequestType) {
        _cancelAnyPreviousPromise(newPromiseType: type)
        _fulfillCharacteristicListPromise = fulfill
        promiseType = .CHARACTERISTICLIST
        initShared(reject, type)
    }
    
    func load(_ fulfill: @escaping (CBCharacteristic) -> Void, _ reject: @escaping (Error) -> Void, type: RequestType) {
        _cancelAnyPreviousPromise(newPromiseType: type)
        _fulfillCharacteristicPromise = fulfill
        promiseType = .CHARACTERISTIC
        initShared(reject, type)
    }
    
    
    func load(_ fulfill: @escaping ([UInt8]) -> Void, _ reject: @escaping (Error) -> Void, type: RequestType) {
        _cancelAnyPreviousPromise(newPromiseType: type)
        _fulfillDataPromise = fulfill
        promiseType = .DATA
        initShared(reject, type)
    }
    
    
    
    func initShared(_ reject: @escaping (Error) -> Void, _ type: RequestType) {
        self.completed = false
        self.rejectId = ""
        self.loadedPromise = true
        self._rejectPromise = reject
        self.type = type
    }
    
    func setDelayedFulfill(_ delayTimeInSeconds: Double) {
        if (promiseType == .VOID) {
            delay(delayTimeInSeconds, { self.fulfill(()) })
        }
        else {
            _reject(BluenetError.CANNOT_SET_TIMEOUT_WITH_THIS_TYPE_OF_PROMISE)
        }
    }
    
    func setDelayedReject(_ delayTimeInSeconds: Double, errorOnReject: BluenetError) {
        let rejectId = getUUID()
        self.rejectId = rejectId
        LOG.debug("PromiseContainer: Setting Delayed Reject delayTimeInSeconds:\(delayTimeInSeconds) rejectId:\(rejectId) errorOnReject:\(errorOnReject) handle:\(self.handle)")
        delay(delayTimeInSeconds, {
            LOG.debug("PromiseContainer: Firing delayed reject delayTimeInSeconds:\(delayTimeInSeconds) rejectId:\(rejectId) errorOnReject:\(errorOnReject) handle:\(self.handle)")
            if (rejectId == self.rejectId) {
                LOG.info("PromiseContainer: actually applying delayed reject delayTimeInSeconds:\(delayTimeInSeconds) rejectId:\(rejectId) errorOnReject:\(errorOnReject) handle:\(self.handle)")
                self.reject(errorOnReject as Error)
            }
            else {
                LOG.debug("PromiseContainer: no need to apply the delayed rejection delayTimeInSeconds:\(delayTimeInSeconds) rejectId:\(rejectId) errorOnReject:\(errorOnReject) handle:\(self.handle)")
            }
        })
    }
    
    
    
    func _clear() {
        type = .NONE
        promiseType = .NONE
        rejectId = ""
        completed = false
        loadedPromise = false
        _fulfillVoidPromise               = {_ in }
        _fulfillIntPromise                = {_ in }
        _fulfillServiceListPromise        = {_ in }
        _fulfillCharacteristicListPromise = {_ in }
        _fulfillCharacteristicPromise     = {_ in }
        _fulfillDataPromise               = {_ in }
        _rejectPromise                    = {_ in }
    
    }
    
    func clearDueToReset() {
        LOG.error("BLE RESET TRIGGERED.")
        if (self.completed == false && self.loadedPromise == true) {
            // An exception is added so disconnect is always safe to repeat.
            // Usually, there is an extra disconnect in catch statements just in case.
            if (self.type == .DISCONNECT) {
                self.fulfill(())
                self._clear()
            }
            else {
                self.reject(BluenetError.BLE_RESET)
                self._clear()
            }
        }
        else {
            self._clear()
        }
    }
    

    func _cancelAnyPreviousPromise(newPromiseType: RequestType) {
        if (self.completed == false && self.loadedPromise == true) {
            // An exception is added so disconnect is always safe to repeat.
            // Usually, there is an extra disconnect in catch statements just in case.
            if (self.type == .DISCONNECT && newPromiseType == .DISCONNECT) {
                self.fulfill(())
                self._clear()
            }
            else {
                LOG.error("DEALLOCATING PROMISE OF TYPE \(self.type) \(self.promiseType) TO SET: \(newPromiseType) \(self.handle)")
                self.reject(BluenetError.REPLACED_WITH_OTHER_PROMISE)
                self._clear()
            }
        }
    }
    
    func fulfill() {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .VOID) {
                _fulfillVoidPromise(())
            }
            else {
                _reject(BluenetError.WRONG_TYPE_OF_PROMISE)
            }
            _clear()
        }
    }
    
    func fulfill(_ data: Void) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .VOID) {
                _fulfillVoidPromise(())
            }
            else {
                _reject(BluenetError.WRONG_TYPE_OF_PROMISE)
            }
            _clear()
        }
    }
    
    func fulfill(_ data: Int) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .INT) {
                _fulfillIntPromise(data)
            }
            else {
                _reject(BluenetError.WRONG_TYPE_OF_PROMISE)
            }
        }
        _clear()
    }
    
    func fulfill(_ data: [CBService]) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .SERVICELIST) {
                _fulfillServiceListPromise(data)
            }
            else {
                _reject(BluenetError.WRONG_TYPE_OF_PROMISE)
            }
        }
        _clear()
    }
    
    func fulfill(_ data: [CBCharacteristic]) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .CHARACTERISTICLIST) {
                _fulfillCharacteristicListPromise(data)
            }
            else {
                _reject(BluenetError.WRONG_TYPE_OF_PROMISE)
            }
        }
        _clear()
    }
    
    func fulfill(_ data: CBCharacteristic) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .CHARACTERISTIC) {
                _fulfillCharacteristicPromise(data)
            }
            else {
                _reject(BluenetError.WRONG_TYPE_OF_PROMISE)
            }
        }
        _clear()
    }
    
    func fulfill(_ data: [UInt8]) {
        if (self.completed == false) {
            self.completed = true
            if (promiseType == .DATA) {
                _fulfillDataPromise(data)
            }
            else {
                _reject(BluenetError.WRONG_TYPE_OF_PROMISE)
            }
        }
        _clear()
    }

    
    func reject(_ error: Error) {
        if (self.completed == false) {
            self.completed = true
            _reject(error)
        }
        _clear()
    }
    
    func _reject(_ error: Error) {
        if let handle = self.handle {
            LOG.error("BLUENET_LIB: PromiseContainer error \(error) \(handle)")
        }
        else {
            LOG.error("BLUENET_LIB: PromiseContainer error \(error) NO_HANDLE")
        }
        _rejectPromise(error)
    }
    
}
