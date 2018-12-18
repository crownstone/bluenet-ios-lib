//
//  PeripheralStateManager.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 04/12/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

class PeripheralStateManager {
    var settings: BluenetSettings
    var blePeripheralManager : BlePeripheralManager!
    var elements = [BroadcastElement]()
    
    var runningBroadcastCycle = false
    var backgroundEnabled: Bool
    let eventBus : EventBus!
    
    var timeOffsetMap = [String: Double]() // track time difference between crownstones and this phone per referenceId
    var timeStoneMap  = [String: Double]() // track time difference between crownstones and this phone per referenceId
    
    init(eventBus: EventBus, settings: BluenetSettings, backgroundEnabled: Bool = true) {
        self.blePeripheralManager = BlePeripheralManager()
        self.settings = settings
        self.eventBus = eventBus
        self.backgroundEnabled = backgroundEnabled
        
        // track time difference between crownstones and this phone per referenceId
        _ = self.eventBus.on("verifiedAdvertisementData", self._trackStoneTime)
    }
    
    public func applicationWillEnterForeground() {
        self.stopBackgroundBroadcasts()
    }
    
    public func applicationDidEnterBackground() {
        self.stopActiveBroadcasts()
        self.startBackgroundBroadcasts()
    }
    
    
    func setBackgroundOperations(newBackgroundState: Bool) {
        self.backgroundEnabled = newBackgroundState
    }
    

    func loadElement(element: BroadcastElement) {
        self._handleDuplicates(incomingElement: element)
        
        self.elements.append(element)
        self.broadcast()
    }

    func broadcast() {
        if (self.runningBroadcastCycle) {
            // update the buffer, a tick is scheduled anyway
            self._broadcastElements()
        }
        else {
            self.tick()
        }
    }
    
    
    func stopBroadcasting() {
        self.blePeripheralManager.stopAdvertising()
    }
    
    
    func stopActiveBroadcasts() {
        // this will fail all promises and clear the buffers.
        // background broadcasting should be enabled after this.
        for element in self.elements {
            element.fail()
        }
        
        self.elements.removeAll()
        self.stopBroadcasting()
    }
    
    func startBackgroundBroadcasts() {
        // TODO: This will map the sphereUID and the locationId to the overflow area
        
    }
    
    
    func stopBackgroundBroadcasts() {
        self.stopBroadcasting()
    }
    
    
    func tick() {
        self._updateElementState()
        
        if (self.elements.count > 0) {
            self.runningBroadcastCycle = true
            self._broadcastElements()
            delay( 0.25, { self.tick() })
        }
        else {
            self.runningBroadcastCycle = false
            self.stopBroadcasting()
        }
    }
    
    // MARK: Dev
    
    
    func advertiseArray(uuids: [UInt16]) {
        let broadcastUUIDs = BroadcastProtocol.convertUInt16ListToUUID(uuids)
        self.blePeripheralManager.startAdvertisingArray(uuids: broadcastUUIDs)
    }
  
    
    // MARK: Util
    
    
    func _handleDuplicates(incomingElement: BroadcastElement) {
        switch (incomingElement.type) {
        case .multiSwitch:
            self._removeSimilarElements(incomingElement)
        default:
            return
        }
    }
    
    func _removeSimilarElements(_ incomingElement: BroadcastElement) {
        // check if blocks are finished
        for (i, element) in self.elements.enumerated().reversed() {
            if element.referenceId == incomingElement.referenceId && element.type == incomingElement.type && element.target == incomingElement.target {
                element.fail()
                self.elements.remove(at: i)
            }
        }
    }
    
    
    func _updateElementState() {
        for element in self.elements {
            element.stoppedBroadcasting()
        }
        
        // check if blocks are finished
        for (i, element) in self.elements.enumerated().reversed() {
            if element.completed {
                self.elements.remove(at: i)
            }
        }
        
        self.elements.sort(by: { element1, element2 in return element1.endTime < element2.endTime })
    }
    
    
    func _broadcastElements() {
        // check in which referenceId the first block to be advertised lives and what it's type is.
        let broadcastType = self.elements[0].type
        let broadcastReferenceId = self.elements[0].referenceId
        
        // create a buffer that will be broadcast
        let bufferToBroadcast = BroadcastBuffer(referenceId: broadcastReferenceId, type: broadcastType)

        // singular elements will immediately mark the buffer as full.
        for element in self.elements {
            if (bufferToBroadcast.accepts(element)) {
                bufferToBroadcast.loadElement(element)
                // if the buffer is now full, stop the loop.
                if (bufferToBroadcast.isFull()) {
                    break
                }
            }
        }
       
        // set everything in motion to advertise this buffer.
        self._broadcastBuffer(bufferToBroadcast)
    }
    
  
    func _broadcastBuffer(_ bufferToBroadcast: BroadcastBuffer) {
        let referenceIdOfBuffer = bufferToBroadcast.referenceId
        var time = getCurrentTimestampForCrownstone()
        if let offset = self.timeOffsetMap[referenceIdOfBuffer] {
            time -= offset
        }
        let packet = bufferToBroadcast.getPacket(validationNonce: NSNumber(value:time).uint32Value)
        do {
            let otherUUIDs = try BroadcastProtocol.getUInt16ServiceNumbers(
                locationState: self.settings.locationState,
                protocolVersion: 1,
                accessLevel: self.settings.userLevel,
                time: getCurrentTimestampForCrownstone()
            )
            
            var nonce = [UInt8]()
            for uuidNum in otherUUIDs {
                nonce += Conversion.uint16_to_uint8_array(uuidNum)
            }
            
            do {
                let encryptedUUID = try BroadcastProtocol.getEncryptedServiceUUID(referenceId: referenceIdOfBuffer, settings: self.settings, data: packet, nonce: nonce)
                
                var broadcastUUIDs = BroadcastProtocol.convertUInt16ListToUUID(otherUUIDs)
                print("Short UUIDs to Broadcast:", otherUUIDs)
                broadcastUUIDs.append(encryptedUUID)
                print("Long UUID to Broadcast:", encryptedUUID)
                self.blePeripheralManager.startAdvertisingArray(uuids: broadcastUUIDs)
                bufferToBroadcast.blocksAreBroadcasting()
            }
            catch let err {
                print("Could not get uint16 ids", err)
            }
        }
        catch let err {
            print("Could not get encrypted service uuid", err)
        }
    }

    
    // track time difference between crownstones and this phone per referenceId
    func _trackStoneTime(data: Any) {
        if let castData = data as? Advertisement {
            if let scanResponse = castData.scanResponse {
                // only use times that are set
                if scanResponse.timeSet == false {
                    return
                }
                
                if let refId = castData.referenceId {
                    let currentTimestamp = getCurrentTimestampForCrownstone()
                    let diff = currentTimestamp - scanResponse.timestamp
                    
                    self.timeStoneMap[castData.handle] = scanResponse.timestamp
                    
                    if diff > 300 {
                        print("WARN: LARGE TIME DIFFERENCE!", diff)
                    }
                    
                    if (self.timeOffsetMap[refId] != nil) {
                        self.timeOffsetMap[refId] = 0.9 * self.timeOffsetMap[refId]! + 0.1*diff
                    }
                    else {
                        self.timeOffsetMap[refId] = diff
                    }
                }
            }
        }
    }
    
}
