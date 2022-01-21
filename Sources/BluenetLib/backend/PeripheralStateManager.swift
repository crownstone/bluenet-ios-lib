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

/**
 
 The PeripheralStateManager (PSM)
 
 This class is the one governing what is broadcasted and how it does this.
 
 We differentiate between 3 states:
 1 - foreground base broadcasts
 2 - foreground active command broadcasts
 3 - background broadcasts
 
 
 1 - Foreground base broadcasts
 
 When advertising is enabled, and we're in the foreground, the base broadcast cycle is started. This is done with the baseRefreshTick.
 The payload of the base broadcast is updated every 30 seconds. If a new tick is triggered while an active broadcast(2) is running,
 we postpone the tick and resume it when the active commands end.
 
 The base broadcast has an emptry buffer at the moment, but it does carry the sphereUID and locationUID for the new behaviour localization update.
 It has to refresh to keep the nonce valid. See protocol for more info.
 
 
 2 - Active Command Broadcasts:
 Commands are loaded into the PSM in elements. These are entered into the loadElement method.
 These elements are class instances of BroadcastElement. They are queued in the PSM, appended and tracked.
 Once an element is loaded, the commandCycle starts.
 
 Each element keeps track of how long it has been broadcasted.
 
 CommandCycle:
    It updates the payload every 0.25 seconds. This is called the Command Tick (commandTick)
    The payload is determined by the first element in the queue. The referenceId and type of this element is applied to the entire BroadcastBuffer
    We then loop through the other elements, to see if they can join in the payload. We can fit a number of multiswitch commands in a buffer.
    Once a commandCycle is over (0.25 seconds), the _updateElementState method will sort the element list depending on broadcast timestamp. This interleaves
    the elements elegantly.
 
 When all required elements have been broadcast and the queue is empty, the command cycle ends and the baseTick continues.
 
 
 3 - Background Broadcasts
 
 On iOS we are stuck with the different types between foreground and background broadcasts.
 The background uses the same baseRefreshTick with the 30 second interval. The updateBaseAdvertisement is the one determining foregroudn or background.
 
---------------------
 
 Switching between 1 and 3:
 
 There are lifecycle methods
     func applicationWillEnterForeground()
     func applicationDidEnterBackground()
 which are called by the application using the lib to ensure correct switching between foreground and background.
 On switching from foreground to background, all promises for all pending and busy elements are failed.
 
 --------------------
 
 The advertising boolean is a master enable/disable for the base ticks 1 and 3. It is triggered by the
 startAdvertising() and the stopAdvertising() functions.
 
 backgroundEnabled is an override to kill background advertising. The advertising will stop when the phone enters the background if this is false.
 
 the settings.devicePreferences contain the use useBackgroundBroadcasts and useBaseBroadcasts overrides.
 
 **/

struct TimeKeeperData {
    var data: Double
    var updatedAt: Double
}

public class PeripheralStateManager {
    let lock = NSRecursiveLock()
    
    var settings: BluenetSettings
    var blePeripheralManager : BlePeripheralManager!
    var elements = [BroadcastElement]()
    
    var advertising = false
    var cachedAdvertising = false
    var baseRefreshTickPostponed = false
    
    var runningBroadcastCycle = false
    var runningCommandCycle   = false // this means there are active commands being broadcasted
    var backgroundEnabled: Bool
    let eventBus : EventBus!
    var broadcastCounter : UInt8 = 0
    
    var timeOffsetMap = [String: TimeKeeperData]() // track time difference between crownstones and this phone per referenceId
    var timeStoneMap  = [String: TimeKeeperData]() // track time difference between crownstones and this phone per referenceId
    
    init(eventBus: EventBus, settings: BluenetSettings, backgroundEnabled: Bool = true) {
        self.settings = settings
        self.eventBus = eventBus
        self.backgroundEnabled = backgroundEnabled
        #if os(iOS)
            self.blePeripheralManager = BlePeripheralManager(eventBus: self.eventBus)
        #endif
        
        #if os(watchOS)
            self.blePeripheralManager = BlePeripheralManager()
        #endif
        
        // track time difference between crownstones and this phone per referenceId
        _ = self.eventBus.on("verifiedAdvertisementData", self._trackStoneTime)
        _ = self.eventBus.on("newKeysets",              { _ in self.updateAdvertisements() })
        _ = self.eventBus.on("newLocationState",       { _ in self.updateAdvertisements() })
        _ = self.eventBus.on("newDevicePreferences",   { _ in self.updateAdvertisements() })
    }
    
    
    #if os(iOS)
    func startPeripheral() {
        LOG.info("BluenetBroadcast: Starting peripheral...")
        self.blePeripheralManager.startPeripheral()
    }
    
    func checkBroadcastAuthorization() -> String {
        LOG.info("BluenetBroadcast: Checking authorization...")
        return self.blePeripheralManager.checkBroadcastAuthorization()
    }
    #endif
    
 

    /**   BACKGROUND STATE HANDLING METHODS **/
    func applicationWillEnterForeground() {
        LOG.info("BluenetBroadcast: applicationWillEnterForeground...")
        self.stopBackgroundBroadcasts()
        self.startForegroundBroadcasts()
    }
    
    func applicationDidEnterBackground() {
        LOG.info("BluenetBroadcast: applicationDidEnterBackground...")
        self.stopForegroundBroadcasts()
        self.startBackgroundBroadcasts()
    }
    
    func setBackgroundOperations(newBackgroundState: Bool) {
        LOG.info("BluenetBroadcast: setBackgroundOperations \(newBackgroundState)")
        self.backgroundEnabled = newBackgroundState
        
        // disable base background advertisements
        if newBackgroundState == false && self.settings.backgroundState && self.runningCommandCycle == false {
            self.stopBroadcasting()
        }
    }
    /** \ BACKGROUND STATE HANDLING METHODS **/
    
    
    func updateAdvertisements() {
        LOG.info("BluenetBroadcast: updateAdvertisements")
        if (self.runningCommandCycle) {
            self._broadcastElements()
        }
        else if (self.runningBroadcastCycle) {
            self.updateBaseAdvertisement()
        }
    }
    
    #if os(iOS)
    /**   GLOBAL ADVERTISING STATE HANDLING METHODS, this is not used for watchOS as it has no background **/
    func pauseAdvertising() {
        LOG.info("BluenetBroadcast: pauseAdvertising")
        self.cachedAdvertising = true
        if self.advertising {
            self.stopAdvertising()
        }
    }
    
    func resumeAdvertising() {
        LOG.info("BluenetBroadcast: resumeAdvertising")
        if self.cachedAdvertising {
            self.startAdvertising()
        }
    }
    
    func startAdvertising() {
        LOG.info("BluenetBroadcast: startAdvertising")
        self.advertising = true
        if self.settings.backgroundState {
            self.startBackgroundBroadcasts()
        }
        else {
            self.startForegroundBroadcasts()
        }
    }
    
    func stopAdvertising() {
        LOG.info("BluenetBroadcast: stopAdvertising")
        self.advertising = false
        if self.settings.backgroundState {
            self.stopBackgroundBroadcasts()
        }
        else {
            self.stopForegroundBroadcasts()
        }
    }
    #else
    func pauseAdvertising() {}
    func resumeAdvertising() {}
    #endif
    
    func stopBroadcasting() {
        LOG.info("BluenetBroadcast: stopBroadcasting")
        self.blePeripheralManager.stopAdvertising()
    }
    /** \ GLOBAL ADVERTISING STATE HANDLING METHODS **/
    
    
    
// MARK: Foreground Methods
    /**   FOREGROUND METHODS **/
    func startForegroundBroadcasts() {
        LOG.info("BluenetBroadcast: startForegroundBroadcasts")
        if (self.advertising) {
            self._startForegroundBroadcasts()
        }
    }
    
    func _startForegroundBroadcasts() {
        LOG.info("BluenetBroadcast: _startForegroundBroadcasts")
        if (self.runningBroadcastCycle == false) {
            self.baseRefreshTick()
        }
        else {
            self._refreshForegroundBroadcasts()
        }
    }
    
    func _refreshForegroundBroadcasts() {
        LOG.info("BluenetBroadcast: _refreshForegroundBroadcasts")
        
        if (self.settings.devicePreferences.useBaseBroadcasts == false) {
            return self.stopBroadcasting()
        }
        
        if let referenceId = self.settings.locationState.referenceId {
            if self.settings.sunsetSecondsSinceMidnight != nil {
                LOG.info("BluenetBroadcast: broadcasting foreground basepacket...")
                
                let packet = Broadcast_ForegroundBasePacket(sunriseSecondsSinceMidnight: self.settings.sunriseSecondsSinceMidnight!, sunsetSecondsSinceMidnight: self.settings.sunsetSecondsSinceMidnight!).getPacket()
                let suntimeElement = BroadcastElement(referenceId: referenceId, type: .timeData, packet: packet, singular: true, duration: 100)
                suntimeElement.loggingToken = "SUN_TIME_FOREGROUND_BASEPACKET"
                let bufferToBroadcast = BroadcastBuffer(referenceId: referenceId, type: .timeData)
                bufferToBroadcast.loadElement(suntimeElement)
                
                self._broadcastBuffer(bufferToBroadcast)
            }
            else {
                let bufferToBroadcast = BroadcastBuffer(referenceId: referenceId, type: .noOp)
                self._broadcastBuffer(bufferToBroadcast)
            }
        }
        else {
            self.stopBroadcasting()
            LOG.error("BluenetBroadcast: _refreshForegroundBroadcasts: No active referenceId")
        }
    }
    
    func stopForegroundBroadcasts() {
        LOG.info("BluenetBroadcast: stopForegroundBroadcasts")
        
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        // this will fail all promises and clear the buffers.
        // background broadcasting should be enabled after this.
        for element in self.elements {
            LOG.info("BluenetBroadcast: stopForegroundBroadcasts \(element.loggingToken)")
            element.fail()
        }
        self.elements.removeAll()
        
        // officially end the command cycle if this was running
        if (self.runningCommandCycle) {
            LOG.info("BluenetBroadcast: stopForegroundBroadcasts endCommandCycle")
            self.endCommandCycle()
        }
        
        // finally, we stop the broadcasting of all active services
        self.stopBroadcasting()
    }
    
    public func stopActiveBroadcasts() {
        LOG.info("BluenetBroadcast: stopActiveBroadcasts")
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
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
    
   
/** \ FOREGROUND METHODS **/
    
    
    /**   COMMAND METHODS **/
    
    func loadElement(element: BroadcastElement, autoExecute: Bool = true) {
        LOG.info("BluenetBroadcast: loadElement \(element.loggingToken)")
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        // existing elements of the same type for the same stone will be overwritten (old switch 0, replaced by new switch 1)
        self._handleDuplicates(incomingElement: element)
        
        self.elements.append(element)
        self.broadcastCounter = self.broadcastCounter &+ 1
        if autoExecute {
            self.broadcastCommand()
        }
    }
    
    /** \ COMMAND METHODS **/
    
    
// MARK: Background Methods
    /**   BACKGROUND METHODS **/
    func startBackgroundBroadcasts() {
        if (self.backgroundEnabled == false || self.settings.devicePreferences.useBackgroundBroadcasts == false) {
            return self.stopBackgroundBroadcasts()
        }
        
        if (self.runningBroadcastCycle == false) {
            self.baseRefreshTick()
        }
        else {
            self._refreshBackgroundBroadcasts()
        }
    }
    
    func _refreshBackgroundBroadcasts() {
        LOG.info("BluenetBroadcast: _refreshBackgroundBroadcasts")
        if (self.backgroundEnabled == false || self.settings.devicePreferences.useBackgroundBroadcasts == false) {
            return self.stopBackgroundBroadcasts()
        }
        
        if BroadcastProtocol.useDynamicBackground() == false {
            let uuids = BroadcastProtocol.getServicesForStaticBackgroundBroadcast(devicePreferences: self.settings.devicePreferences)
            self.blePeripheralManager.startAdvertisingArray(uuids: uuids)
            return
        }
        
        
        if let referenceId = self.settings.locationState.referenceId {
            if let key = self.settings.getLocalizationKey(referenceId: referenceId) {
                let uuids = BroadcastProtocol.getServicesForBackgroundBroadcast(locationState: self.settings.locationState, devicePreferences: self.settings.devicePreferences, key: key)
                self.blePeripheralManager.startAdvertisingArray(uuids: uuids)
            }
        }
    }
    
    func stopBackgroundBroadcasts() {
        self.stopBroadcasting()
    }
/** \ BACKGROUND METHODS **/
    
    
// MARK: functionality
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
                // updateBaseAdvertisement assumes there is an active base tick.
                // If it was postponed, we can't use this and have to go through the baseRefreshTick
                self.updateBaseAdvertisement()
            }
        }
    }
    
    func commandTick() {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
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
        LOG.info("BluenetBroadcast: baseRefreshTick")
        // we check if we are allowed to do base refreshes or if we should stop. We can only do this if there is no active command cycle
        if (self.runningCommandCycle == false) {
            if self.settings.backgroundState {
                if (self.backgroundEnabled == false || self.settings.devicePreferences.useBackgroundBroadcasts == false) {
                    self.runningBroadcastCycle = false
                    return self.stopBroadcasting()
                }
            }
            else {
                if (self.settings.devicePreferences.useBackgroundBroadcasts == false) {
                    self.runningBroadcastCycle = false
                    return self.stopBroadcasting()
                }
            }
        }
            
        if (self.advertising) {
            self.runningBroadcastCycle = true
            if (self.runningCommandCycle == true) {
                self.baseRefreshTickPostponed = true
            }
            else {
                self.updateBaseAdvertisement()
                if self.settings.backgroundState && BroadcastProtocol.useDynamicBackground() == false {
                    self.runningBroadcastCycle = false
                }
                else {
                    delay( 30, self.baseRefreshTick )
                }
            }
        }
        else {
            self.runningBroadcastCycle = false
        }
    }
    
    
    func updateBaseAdvertisement() {
        #if os(iOS)
        LOG.info("BluenetBroadcast: updateBaseAdvertisement")
//         print("TEST: updateBaseAdvertisement")
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
            self._removeSimilarTargetedElements(incomingElement)
        default:
            self._removeSimilarElements(incomingElement)
        }
    }
    
    func _removeSimilarTargetedElements(_ incomingElement: BroadcastElement) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        // check if blocks are finished
        for (i, element) in self.elements.enumerated().reversed() {
            if element.referenceId == incomingElement.referenceId && element.type == incomingElement.type && element.target == incomingElement.target {
                element.fail()
                LOG.info("BluenetBroadcast: _removeSimilarTargetedElements \(element.loggingToken)")
                self.elements.remove(at: i)
            }
        }
    }
    
    func _removeSimilarElements(_ incomingElement: BroadcastElement) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        // check if blocks are finished
        for (i, element) in self.elements.enumerated().reversed() {
            if element.referenceId == incomingElement.referenceId && element.type == incomingElement.type {
                element.fail()
                LOG.info("BluenetBroadcast: _removeSimilarElements \(element.loggingToken)")
                self.elements.remove(at: i)
            }
        }
    }
    
    
    func _updateElementState() {
        LOG.info("BluenetBroadcast: _updateElementState")
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        for element in self.elements {
            element.stoppedBroadcasting()
        }
        
        // check if blocks are finished
        for (i, element) in self.elements.enumerated().reversed() {
            if element.completed {
                LOG.info("BluenetBroadcast: _updateElementState remove completed \(element.loggingToken)")
                self.elements.remove(at: i)
            }
        }
        
        self.elements.sort(by: { element1, element2 in return element1.endTime < element2.endTime })
    }
    
    
    func _broadcastElements() {
        LOG.info("BluenetBroadcast: _broadcastElements")
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        // check in which referenceId the first block to be advertised lives and what it's type is.
        if (self.elements.count == 0) {
            LOG.info("BluenetBroadcast: _broadcastElements no elements left to broadcast.")
            self.updateBaseAdvertisement()
            return;
        }
        
        let broadcastType = self.elements[0].type
        let broadcastReferenceId = self.elements[0].referenceId
        
        // create a buffer that will be broadcast
        let bufferToBroadcast = BroadcastBuffer(referenceId: broadcastReferenceId, type: broadcastType)

        // singular elements will immediately mark the buffer as full.
        for element in self.elements {
            if (bufferToBroadcast.accepts(element)) {
                bufferToBroadcast.loadElement(element)
                LOG.info("BluenetBroadcast: _broadcastElements load element to buffer \(element.loggingToken)")
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
        LOG.info("BluenetBroadcast: _broadcastBuffer")
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        let referenceIdOfBuffer = bufferToBroadcast.referenceId
        var time = getCurrentTimestampForCrownstone()
        if let offset = self.timeOffsetMap[referenceIdOfBuffer] {
            time -= offset.data
        }
        
        let userLevelForReferenceId = self.settings.getUserLevel(referenceId: referenceIdOfBuffer)
        
        if (userLevelForReferenceId == .unknown) {
            print("Error in _broadcastBuffer Invalid referenceId")
            return
        }
        
        if let localizationKey = self.settings.getLocalizationKey(referenceId: referenceIdOfBuffer) {
            let packet = bufferToBroadcast.getPacket(devicePreferences: self.settings.devicePreferences)
            
            do {
                let otherUUIDs = try BroadcastProtocol.getUInt16ServiceNumbers(
                    broadcastCounter: self.broadcastCounter,
                    locationState: self.settings.locationState,
                    devicePreferences: self.settings.devicePreferences,
                    protocolVersion: 0,
                    accessLevel: userLevelForReferenceId,
                    key: localizationKey
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
                    LOG.error("BluenetBroadcast: _broadcastBuffer Could not get uint16 ids \(err)")
                }
            }
            catch let err {
                LOG.error("BluenetBroadcast: _broadcastBuffer Could not get encrypted service uuid \(err)")
            }
        }
        else {
            LOG.warn("BluenetBroadcast: _broadcastBuffer No key to broadcast with!")
        }
    }

    
    // track time difference between crownstones and this phone per referenceId
    func _trackStoneTime(data: Any) {
        // ensure single thread usage
        lock.lock()
        defer { lock.unlock() }
        
        if let castData = data as? Advertisement {
            if let scanResponse = castData.scanResponse {
                // only use times that are set
                if scanResponse.timeSet == false {
                    return
                }
                
                if let refId = castData.referenceId {
                    let now = Date().timeIntervalSince1970
                    let currentTimestamp = getCurrentTimestampForCrownstone()
                    let diff = currentTimestamp - scanResponse.timestamp
                    
                    self.timeStoneMap[castData.handle] = TimeKeeperData(data: scanResponse.timestamp, updatedAt: now)
                    
                    if abs(diff) > 120 {
                        LOG.info("WARN: LARGE TIME DIFFERENCE! \(diff)")
                    }
                    
                    if (self.timeOffsetMap[refId] != nil) {
                        self.timeOffsetMap[refId] = TimeKeeperData(data: 0.9 * self.timeOffsetMap[refId]!.data + 0.1*diff, updatedAt: now)
                    }
                    else {
                        self.timeOffsetMap[refId] = TimeKeeperData(data: diff, updatedAt: now)
                    }
                }
            }
        }
    }
    
}
