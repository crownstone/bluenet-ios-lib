//
//  DfuHandler.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth
import iOSDFULibrary


open class DfuHandler: DFUServiceDelegate, DFUProgressDelegate, LoggerDelegate {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    var deviceList : [String: AvailableDevice]!
    var wasScanning = false
    
    fileprivate var dfuController : DFUServiceController?
    var pendingDFUPromiseFulfill : (Void) -> Void = {_ in }
    var pendingDFUPromiseReject : (BleError) -> Void  = {_ in }
    var promisePending = false
    
    let secureDFU = false
    
    init (bleManager: BleManager, eventBus: EventBus, settings: BluenetSettings, deviceList: [String: AvailableDevice]) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
        self.deviceList = deviceList
    }
    
    
    /**
     *
     * This method requires the Crownstone to be in DFU mode and not in an active ble connection.
     * We provide our CBCentralManager, but it's delegate is pointed their BaseDFUPeripheral.
     * After the DFU finishes (fail or success) we have to reassign the delegate to our bleManager using the self.bleManager.reassignDelegate method.
     *
     **/
    open func startDFU(handle: String, firmwareURL: URL) -> Promise<Void> {
        if (self.promisePending == true) {
            self.rejectPromise(BleError.DFU_OVERRULED)
            _ = dfuController?.abort()
            dfuController = nil
        }
        
        return Promise<Void> { fulfill, reject in
            self.promisePending = true
            let dfuPeripheral = self.bleManager.getPeripheral(handle)

            self.pendingDFUPromiseReject = reject
            self.pendingDFUPromiseFulfill = fulfill
            
            guard dfuPeripheral != nil else {
                self.rejectPromise(BleError.COULD_NOT_FIND_PERIPHERAL)
                return
            }
            
        
            let dfuInitiator = DFUServiceInitiator(centralManager: self.bleManager.centralManager!, target: dfuPeripheral!)
            dfuInitiator.delegate = self
            dfuInitiator.progressDelegate = self
            dfuInitiator.logger = self
            dfuInitiator.packetReceiptNotificationParameter = 22
            
            // This enables the experimental Buttonless DFU feature from SDK 12.
            // Please, read the field documentation before use.
            dfuInitiator.enableUnsafeExperimentalButtonlessServiceInSecureDfu = false
            
            let selectedFirmware = DFUFirmware(urlToZipFile: firmwareURL)
            dfuController = dfuInitiator.with(firmware: selectedFirmware!).start()
        }
    }
    
    
    //MARK: - DFUServiceDelegate
    
    public func dfuStateDidChange(to state: DFUState) {
        if (self.promisePending) {
            
            switch state {
            case .disconnecting:
                print("disconnecting")
            case .completed:
                self.fulfillPromise()
                print("completed")
            case .aborted:
                self.rejectPromise(BleError.DFU_ABORTED)
                print("aborted")
            default:
                print("default")
            }
            
            print("Changed state to: \(state.description())")

        }
    }
    
    public func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        LOG.error("Error \(error.rawValue): \(message)")
        self.rejectPromise(BleError.DFU_ERROR)
    }
    
    //MARK: - DFUProgressDelegate
    
    public func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        let percentage = NSNumber(value: part).doubleValue/(NSNumber(value: totalParts).doubleValue);
        var data = [String: NSNumber]()
        data["percentage"]  = NSNumber(value: percentage)
        data["part"]        = NSNumber(value: part)
        data["totalParts"]  = NSNumber(value: totalParts)
        data["progress"]    = NSNumber(value: progress)
        data["currentSpeedBytesPerSecond"] = NSNumber(value: currentSpeedBytesPerSecond)
        data["avgSpeedBytesPerSecond"]     = NSNumber(value: avgSpeedBytesPerSecond)
        self.eventBus.emit("dfuProgress", data)
        
        LOG.info("\(part) out of \(totalParts) so progress \(progress) at a speed of \(currentSpeedBytesPerSecond/1024)")
    }
    
    //MARK: - LoggerDelegate
    
    public func logWith(_ level: LogLevel, message: String) {
        print("\(level.name()): \(message)")
    }

    
    func rejectPromise(_ err: BleError) {
        if (self.promisePending) {
            self.promisePending = false
            self.pendingDFUPromiseReject(err)
        }
        self.bleManager.reassignDelegate()
    }
    
    func fulfillPromise() {
        print("HERE")
        if (self.promisePending) {
            self.promisePending = false
            self.pendingDFUPromiseFulfill()
        }
        self.bleManager.reassignDelegate()
    }
    
}
