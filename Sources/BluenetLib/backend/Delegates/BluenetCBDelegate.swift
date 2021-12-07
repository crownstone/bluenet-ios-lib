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
    var BleManager : BleManager!
    
    public init(bleManager: BleManager) {
        super.init()
        self.BleManager = bleManager
    }
    
    
    // MARK: CENTRAL MANAGER DELEGATE
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        BleManager.cBmanagerUpdatedState = true
        
        if #available(iOS 10.0, *) {
            switch central.state{
            case CBManagerState.unauthorized:
                BleManager.BleState = .unauthorized
                BleManager.eventBus.emit("bleStatus", "unauthorized");
                LOG.info("BLUENET_LIB: This app is not authorised to use Bluetooth low energy")
            case CBManagerState.poweredOff:
                BleManager.BleState = .poweredOff
                BleManager.eventBus.emit("bleStatus", "poweredOff");
                LOG.info("BLUENET_LIB: Bluetooth is currently powered off.")
            case CBManagerState.poweredOn:
                BleManager.BleState = .poweredOn
                BleManager.eventBus.emit("bleStatus", "poweredOn");
                LOG.info("BLUENET_LIB: Bluetooth is currently powered on and available to use.")
            case CBManagerState.resetting:
                BleManager.BleState = .resetting
                BleManager.eventBus.emit("bleStatus", "resetting");
                LOG.info("BLUENET_LIB: Bluetooth is currently resetting.")
            case CBManagerState.unknown:
                BleManager.BleState = .unknown
                BleManager.eventBus.emit("bleStatus", "unknown");
                LOG.info("BLUENET_LIB: Bluetooth state is unknown.")
            case CBManagerState.unsupported:
                BleManager.BleState = .unsupported
                BleManager.eventBus.emit("bleStatus", "unsupported");
                LOG.info("BLUENET_LIB: Bluetooth is unsupported?")
            default:
                BleManager.eventBus.emit("bleStatus", "unknown")
                LOG.info("BLUENET_LIB: Bluetooth is other: \(central.state) ")
                break
            }
        } else {
            // Fallback on earlier versions
            switch central.state.rawValue {
            case 3: // CBCentralManagerState.unauthorized :
                BleManager.BleState = .unauthorized
                BleManager.eventBus.emit("bleStatus", "unauthorized");
                LOG.info("BLUENET_LIB: This app is not authorised to use Bluetooth low energy")
            case 4: // CBCentralManagerState.poweredOff:
                BleManager.BleState = .poweredOff
                BleManager.eventBus.emit("bleStatus", "poweredOff");
                LOG.info("BLUENET_LIB: Bluetooth is currently powered off.")
            case 5: //CBCentralManagerState.poweredOn:
                BleManager.BleState = .poweredOn
                BleManager.eventBus.emit("bleStatus", "poweredOn");
                LOG.info("BLUENET_LIB: Bluetooth is currently powered on and available to use.")
            default:
                BleManager.eventBus.emit("bleStatus", "unknown");
                break
            }
        }
    }
    
    
    /**
     This delegate callback is a result from the BLE scan. It contains Advertisementdata which has serviceData.
     */
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // battery saving means we do not decrypt everything nor do we emit the data into the app. All incoming advertisements are ignored
        if (BleManager.batterySaving == true) {
            return
        }

        let emitData = Advertisement(
            handle: peripheral.identifier.uuidString,
            name: peripheral.name,
            rssi: RSSI,
            serviceData: advertisementData["kCBAdvDataServiceData"] as? [CBUUID: Data],
            serviceUUID: advertisementData["kCBAdvDataServiceUUIDs"] as? [CBUUID]
        )
    
        BleManager.eventBus.emit("rawAdvertisementData",emitData)
    }
    
    
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let handle = peripheral.identifier.uuidString
        LOG.info("BLUENET_LIB: in didConnectPeripheral. Connected to \(handle)")
        
        // we do not add a semaphore to the task because the promise callbacks might cause a deadlock.
        if (BleManager.task(handle).type == .CONNECT) {
            BleManager.task(handle).fulfill()
        }
    
        
        BleManager.connectionState(handle).connected()
        // -- Accessing shared resources
        semaphore.wait()
        BleManager.pendingConnections.removeValue(forKey: handle)
        BleManager.connections[handle] = peripheral
        semaphore.signal()
        // -- end of shared resource access.
        
        BleManager.eventBus.emit("connectedToPeripheral", handle)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let handle = peripheral.identifier.uuidString
        LOG.info("BLUENET_LIB: in didFailToConnectPeripheral. Failed to connect to \(handle)")
        var errorVal : Error = BluenetError.CONNECTION_FAILED
        if error != nil {
            errorVal = error!
        }
        
        // we do not add a semaphore to the task because the promise callbacks might cause a deadlock.
        if (BleManager.task(handle).type == .CONNECT) {
            BleManager.task(handle).reject(errorVal)
        }
        
        // -- Accessing shared resources
        semaphore.wait()
        BleManager.pendingConnections.removeValue(forKey: handle)
        // lets just remove it from the connections, just in case. It shouldn't be in here, but if it is, its cleaned up again.
        BleManager.connections.removeValue(forKey: handle)
        semaphore.signal();
        // -- end of shared resource access.
        
        BleManager.eventBus.emit("connectingToPeripheralFailed", handle)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let handle = peripheral.identifier.uuidString
        LOG.info("BLUENET_LIB: in didDisconnectPeripheral for handle: \(handle)")
        
        let pendingTask = BleManager.task(handle)
        
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
                pendingTask.reject(error!)
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
        
        
        BleManager.connectionState(handle).clear()
        
        
        // -- Accessing shared resources
        semaphore.wait()
        
        BleManager.connections.removeValue(forKey: handle)
        BleManager._connectionStates.removeValue(forKey: handle)
        // lets just remove it from the pending connections, just in case. It shouldn't be in here, but if it is, its cleaned up again.
        BleManager.pendingConnections.removeValue(forKey: handle)
       
        semaphore.signal();
        // -- end of shared resource access.
        
        BleManager.notificationBus(handle).reset()
        
        
        BleManager.eventBus.emit("disconnectedFromPeripheral", handle)
    }

}

