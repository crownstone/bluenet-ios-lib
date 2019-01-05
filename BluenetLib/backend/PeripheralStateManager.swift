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
    
    var advertising = false
    
    var baseRefreshTickPostponed = false
    
    var runningBroadcastCycle = false
    var runningCommandCycle = false
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
        _ = self.eventBus.on("newKeysets",           { _ in self.updateAdvertisements() })
        _ = self.eventBus.on("newLocationState",     { _ in self.updateAdvertisements() })
        _ = self.eventBus.on("newDevicePreferences", { _ in self.updateAdvertisements() })
    }
    
  

/**   BACKGROUND STATE HANDLING METHODS **/
    func applicationWillEnterForeground() {
        print("Peripheral received application will enter foreground")
        self.stopBackgroundBroadcasts()
        self.startForegroundBroadcasts()
    }
    
    func applicationDidEnterBackground() {
        print("Peripheral received application did enter background")
        self.stopForegroundBroadcasts()
        self.startBackgroundBroadcasts()
    }
    
    func setBackgroundOperations(newBackgroundState: Bool) {
        self.backgroundEnabled = newBackgroundState
    }
/** \ BACKGROUND STATE HANDLING METHODS **/
    
    
    func updateAdvertisements() {
        if (self.runningCommandCycle) {
            self._broadcastElements()
        }
        else if (self.runningBroadcastCycle) {
            self.updateBaseAdvertisement()
        }
    }
    
    #if os(iOS)
/**   GLOBAL ADVERTISING STATE HANDLING METHODS **/
    func startAdvertising() {
        self.advertising = true
        if self.settings.backgroundState {
            self.startBackgroundBroadcasts()
        }
        else {
            self.startForegroundBroadcasts()
        }
    }
    
    func stopAdvertising() {
        self.advertising = false
        if self.settings.backgroundState {
            self.stopBackgroundBroadcasts()
        }
        else {
            self.stopForegroundBroadcasts()
        }
    }
    #endif
    
    func stopBroadcasting() {
        self.blePeripheralManager.stopAdvertising()
    }
/** \ GLOBAL ADVERTISING STATE HANDLING METHODS **/
    
    
    
// MARK: Foreground Methods
/**   FOREGROUND METHODS **/
    func startForegroundBroadcasts() {
        // print("TEST: startForegroundBroadcasts")
        if (self.advertising) {
            self._startForegroundBroadcasts()
        }
    }
    
    func _startForegroundBroadcasts() {
        // print("TEST: _startForegroundBroadcasts")
        if (self.runningBroadcastCycle == false) {
            self.baseRefreshTick()
        }
        else {
            self._refreshForegroundBroadcasts()
        }
    }
    
    func _refreshForegroundBroadcasts() {
        if let referenceId = self.settings.locationState.referenceId {
            let bufferToBroadcast = BroadcastBuffer(referenceId: referenceId, type: .foregroundBase)
            self._broadcastBuffer(bufferToBroadcast)
        }
        else {
            print("PROBLEM - updateBaseAdvertisement: No active referenceId")
        }
    }
    
    func stopForegroundBroadcasts() {
        // print("TEST: stopForegroundBroadcasts")
        // this will fail all promises and clear the buffers.
        // background broadcasting should be enabled after this.
        for element in self.elements {
            element.fail()
        }
        self.elements.removeAll()
        
        // officially end the command cycle if this was running
        if (self.runningCommandCycle) {
            self.endCommandCycle()
        }
        
        // finally, we stop the broadcasting of all active services
        self.stopBroadcasting()
    }
    
    public func stopActiveBroadcasts() {
        // print("TEST: stopForegroundBroadcasts")
        // this will fail all promises and clear the buffers.
        // background broadcasting should be enabled after this.
        for element in self.elements {
            element.fail()
        }
        self.elements.removeAll()
        
        // officially end the command cycle if this was running
        if (self.runningCommandCycle) {
            self.endCommandCycle()
        }
        
    }
    
    
    /**   COMMAND METHODS **/

    func loadElement(element: BroadcastElement) {
        self._handleDuplicates(incomingElement: element)
        
        self.elements.append(element)
        self.broadcastCommand()
    }

    /** \ COMMAND METHODS **/
/** \ FOREGROUND METHODS **/
    
    
    
    
// MARK: Background Methods
/**   BACKGROUND METHODS **/
    func startBackgroundBroadcasts() {
        // print("TEST: startBackgroundBroadcasts")
        if (self.runningBroadcastCycle == false) {
            self.baseRefreshTick()
        }
        else {
            self._refreshBackgroundBroadcasts()
        }
    }
    
    func _refreshBackgroundBroadcasts() {
        if let referenceId = self.settings.locationState.referenceId {
            if let key = self.settings.getGuestKey(referenceId: referenceId) {
                let uuids = BroadcastProtocol.getServicesForBackgroundBroadcast(locationState: self.settings.locationState, devicePreferences: self.settings.devicePreferences, key: key)
                self.blePeripheralManager.startAdvertisingArray(uuids: uuids)
            }
        }
    }
    
    func stopBackgroundBroadcasts() {
        // print("TEST: stopBackgroundBroadcasts")
        self.stopBroadcasting()
    }
/** \ BACKGROUND METHODS **/
    
    
    

   

    func broadcastCommand() {
        if (self.runningCommandCycle) {
            // update the buffer, a tick is scheduled anyway
            self._broadcastElements()
        }
        else {
            self.startCommandCycle()
        }
    }
    
    func startCommandCycle() {
        self.runningCommandCycle = true
        self.commandTick()
    }
    
    func endCommandCycle() {
        self.runningCommandCycle = false
        if (self.advertising == false) {
            self.stopBroadcasting()
        }
        else {
            if (self.baseRefreshTickPostponed == true) {
                self.baseRefreshTick()
            }
            else {
                self.updateBaseAdvertisement()
            }
        }
    }
    
    func commandTick() {
        // print("TEST: CommandTick")
        self.runningCommandCycle = true
        self._updateElementState()
        if (self.elements.count > 0) {
            self._broadcastElements()
            delay( 0.25, { self.commandTick() })
        }
        else {
            self.endCommandCycle()
        }
    }
    
    func baseRefreshTick() {
        // print("TEST: baseRefreshTick")
        if (self.advertising) {
            self.runningBroadcastCycle = true
            if (self.runningCommandCycle == true) {
                self.baseRefreshTickPostponed = true
            }
            else {
                self.updateBaseAdvertisement()
                delay( 30, self.baseRefreshTick )
            }
        }
        else {
            if (runningBroadcastCycle) {
                self.runningBroadcastCycle = false
            }
        }
    }
    
    
    func updateBaseAdvertisement() {
        #if os(iOS)
        // print("TEST: updateBaseAdvertisement")
        if self.settings.backgroundState {
            self._refreshBackgroundBroadcasts()
        }
        else {
            self._refreshForegroundBroadcasts()
        }
        #endif
    }
    
    
    
   
    
    // MARK: Dev
    func advertiseArray(uuids: [UInt16]) {
        let broadcastUUIDs = BroadcastProtocol.convertUInt16ListToUUID(uuids)
        self.blePeripheralManager.startAdvertisingArray(uuids: broadcastUUIDs)
    }
    
    func advertiseArray(uuids: [CBUUID]) {
        self.blePeripheralManager.startAdvertisingArray(uuids: uuids)
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
        if (settings.setSessionId(referenceId: referenceIdOfBuffer) == false) {
            print("Invalid referenceId")
            return
        }
        
        if let guestKey = self.settings.getGuestKey(referenceId: referenceIdOfBuffer) {
            let packet = bufferToBroadcast.getPacket(validationNonce: NSNumber(value:time).uint32Value)
            do {
                let otherUUIDs = try BroadcastProtocol.getUInt16ServiceNumbers(
                    locationState: self.settings.locationState,
                    devicePreferences: self.settings.devicePreferences,
                    protocolVersion: 1,
                    accessLevel: self.settings.userLevel,
                    key: guestKey
                )
                
                var nonce = [UInt8]()
                for uuidNum in otherUUIDs {
                    nonce += Conversion.uint16_to_uint8_array(uuidNum)
                }
                
                do {
                    let encryptedUUID = try BroadcastProtocol.getEncryptedServiceUUID(referenceId: referenceIdOfBuffer, settings: self.settings, data: packet, nonce: nonce)
                    
                    var broadcastUUIDs = BroadcastProtocol.convertUInt16ListToUUID(otherUUIDs)
                    broadcastUUIDs.append(encryptedUUID)
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
