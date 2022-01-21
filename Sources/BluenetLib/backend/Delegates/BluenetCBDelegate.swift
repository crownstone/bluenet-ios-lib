//
//  BluenetCBDelegate
//  BluenetLib
//
//  Created by Alex de Mulder on 16/10/2017.
//  Copyright © 2017 Alex de Mulder. All rights reserved.
//

import Foundation

import Foundation
import CoreBluetooth
import SwiftyJSON
import PromiseKit

let delegateSemaphore = DispatchSemaphore(value: 1)

public class BluenetCBDelegate: NSObject, CBCentralManagerDelegate {
    var bleManager : BleManager!
    
    public init(bleManager: BleManager) {
        super.init()
        self.bleManager = bleManager
    }
    
    
    // MARK: CENTRAL MANAGER DELEGATE
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bleManager.cBmanagerUpdatedState = true

        switch central.state{
            case CBManagerState.unauthorized:
                bleManager.BleState = .unauthorized
                bleManager.eventBus.emit("bleStatus", "unauthorized");
                LOG.info("BLUENET_LIB: This app is not authorised to use Bluetooth low energy")
            case CBManagerState.poweredOff:
                bleManager.BleState = .poweredOff
                bleManager.eventBus.emit("bleStatus", "poweredOff");
                LOG.info("BLUENET_LIB: Bluetooth is currently powered off.")
            case CBManagerState.poweredOn:
                bleManager.BleState = .poweredOn
                bleManager.eventBus.emit("bleStatus", "poweredOn");
                LOG.info("BLUENET_LIB: Bluetooth is currently powered on and available to use.")
            case CBManagerState.resetting:
                bleManager.BleState = .resetting
                bleManager.eventBus.emit("bleStatus", "resetting");
                LOG.info("BLUENET_LIB: Bluetooth is currently resetting.")
            case CBManagerState.unknown:
                bleManager.BleState = .unknown
                bleManager.eventBus.emit("bleStatus", "unknown");
                LOG.info("BLUENET_LIB: Bluetooth state is unknown.")
            case CBManagerState.unsupported:
                bleManager.BleState = .unsupported
                bleManager.eventBus.emit("bleStatus", "unsupported");
                LOG.info("BLUENET_LIB: Bluetooth is unsupported?")
            default:
                bleManager.eventBus.emit("bleStatus", "unknown")
                LOG.info("BLUENET_LIB: Bluetooth is other: \(central.state) ")
                break
        }
    }
    
    
    /**
     This delegate callback is a result from the BLE scan. It contains Advertisementdata which has serviceData.
     */
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // battery saving means we do not decrypt everything nor do we emit the data into the app. All incoming advertisements are ignored
        if (bleManager.batterySaving == true) {
            return
        }

        let emitData = Advertisement(
            handle: peripheral.identifier.uuidString,
            name: peripheral.name,
            rssi: RSSI,
            serviceData: advertisementData["kCBAdvDataServiceData"] as? [CBUUID: Data],
            serviceUUID: advertisementData["kCBAdvDataServiceUUIDs"] as? [CBUUID]
        )
    
        bleManager.eventBus.emit("rawAdvertisementData",emitData)
    }
    
    
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // ensure single thread usage
        bleManager.lock.lock()
        defer { bleManager.lock.unlock() }
        
        let handle = peripheral.identifier.uuidString
        LOG.info("BLUENET_LIB: in didConnectPeripheral. Connected to \(handle)")
        
        // we do not add a semaphore to the task because the promise callbacks might cause a deadlock.
        if (bleManager.task(handle).type == .CONNECT) {
            bleManager.task(handle).fulfill()
        }
    
        
        bleManager.connectionState(handle).connected()
        bleManager.pendingConnections.removeValue(forKey: handle)
        bleManager.connections[handle] = peripheral
        
        bleManager.eventBus.emit("connectedToPeripheral", handle)
        
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // ensure single thread usage
        bleManager.lock.lock()
        defer { bleManager.lock.unlock() }
        
        let handle = peripheral.identifier.uuidString
        LOG.info("BLUENET_LIB: in didFailToConnectPeripheral. Failed to connect to \(handle)")
        var errorVal : Error = BluenetError.CONNECTION_FAILED
        if error != nil {
            errorVal = error!
        }
        
        // we do not add a semaphore to the task because the promise callbacks might cause a deadlock.
        if (bleManager.task(handle).type == .CONNECT) {
            bleManager.task(handle).reject(errorVal)
        }
        
        bleManager.pendingConnections.removeValue(forKey: handle)
        // lets just remove it from the connections, just in case. It shouldn't be in here, but if it is, its cleaned up again.
        bleManager.connections.removeValue(forKey: handle)
        
        bleManager.eventBus.emit("connectingToPeripheralFailed", handle)
        
    
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // ensure single thread usage
        bleManager.lock.lock()
        defer { bleManager.lock.unlock() }
        
        let handle = peripheral.identifier.uuidString
        LOG.info("BLUENET_LIB: in didDisconnectPeripheral for handle: \(handle)")
        
        let pendingTask = bleManager.task(handle)
        
        LOG.debug("BLUENET_LIB: got task in didDisconnectPeripheral for handle: \(handle) taskType:\(pendingTask.type)")
        if (pendingTask.type == .NONE) {
            LOG.info("BLUENET_LIB: Peripheral disconnected for handle: \(handle) taskType:\(pendingTask.type)")
        }
        else if (pendingTask.type == .AWAIT_DISCONNECT) {
            LOG.info("BLUENET_LIB: Peripheral disconnected from us succesfully for handle: \(handle) taskType:\(pendingTask.type)")
            pendingTask.fulfill()
        }
        else if (pendingTask.type == .ERROR_DISCONNECT) {
            if (error != nil) {
                LOG.info("BLUENET_LIB: Operation Error_Disconnect: Peripheral disconnected from us for handle: \(handle) taskType:\(pendingTask.type)")
            }
            else {
                LOG.info("BLUENET_LIB: Operation Error_Disconnect: We disconnected from Peripheral for handle: \(handle) taskType:\(pendingTask.type)")
            }
            pendingTask.fulfill()
        }
        else {
            if (error != nil) {
                LOG.info("BLUENET_LIB: Disconnected with error \(error!) for handle: \(handle) taskType:\(pendingTask.type)")
                pendingTask.reject(BluenetError.DISCONNECT_ERROR)
            }
            else {
                LOG.info("BLUENET_LIB: Disconnected succesfully for handle: \(handle) taskType:\(pendingTask.type)")
                // if the pending promise is NOT for disconnect, a disconnection event is a rejection.
                if (pendingTask.type != .DISCONNECT) {
                    pendingTask.reject(BluenetError.DISCONNECTED)
                }
                else {
                    pendingTask.fulfill()
                }
            }
        }
        
        
        bleManager.connectionState(handle).clear()
        bleManager.connections.removeValue(forKey: handle)
        bleManager._connectionStates.removeValue(forKey: handle)
        // lets just remove it from the pending connections, just in case. It shouldn't be in here, but if it is, its cleaned up again.
        bleManager.pendingConnections.removeValue(forKey: handle)
        bleManager.notificationBus(handle).reset()
    
        bleManager.eventBus.emit("disconnectedFromPeripheral", handle)
    }

}

