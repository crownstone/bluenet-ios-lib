//
//  AvailableDevice.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 17/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.

import Foundation

let AMOUNT_OF_REQUIRED_MATCHES = 3

open class AvailableDevice {
    var rssiHistory = [Double: Int]()
    var rssi : Int!
    var name : String?
    var handle : String
    var crownstoneId : UInt8 = 0
    var lastUpdate : Double = 0
    var cleanupCallback : voidCallback
    var avgRssi : Double!
    var uniqueIdentifier : NSNumber = 0
    var verified = false
    var dfu = false
    
    // config
    let timeout : Double = 20 //seconds
    let rssiTimeout : Double = 3 //seconds
    var consecutiveMatches : Int = 0
    
    init(_ data: Advertisement, _ cleanupCallback: @escaping voidCallback) {
        self.name = data.name
        self.handle = data.handle
        self.cleanupCallback = cleanupCallback
        self.avgRssi = data.rssi.doubleValue
        if (data.isCrownstoneFamily) {
            if (data.isSetupPackage()) {
                self.verified = true;
            }
            else if (data.isDFUPackage()) {
                self.dfu = true;
            }
            else {
                self.crownstoneId = data.scanResponse!.crownstoneId
            }
        }
        self.update(data)
    }
    
    func checkTimeout(_ referenceTime : Double) {
        // if they are equal, no update has happened since the scheduling of this check.
        if (self.lastUpdate == referenceTime) {
            self.cleanupCallback()
        }
    }
    
    func clearRSSI(_ referenceTime : Double) {
        self.rssiHistory.removeValue(forKey: referenceTime)
        self.calculateRssiAverage()
    }
    
    func update(_ data: Advertisement) {
        self.rssi = data.rssi.intValue
        
        // make a local copy for the closures.
        let updatetime = Date().timeIntervalSince1970
        self.lastUpdate = updatetime
        
        self.rssiHistory[self.lastUpdate] = self.rssi;
        
        if (data.isInDFUMode == true) {
            self.verified = true;
            self.consecutiveMatches = 0
        }
        else {
            self.verify(data.scanResponse)
        }
        
        self.calculateRssiAverage()
        
        delay(self.timeout, { self.checkTimeout(updatetime) });
        delay(self.rssiTimeout, { self.clearRSSI(updatetime) });
    }
    
    
    // check if we consistently get the ID of this crownstone.
    func verify(_ data: ScanResponsePacket?) {
        if let response = data {
            if (response.isSetupPackage()) {
                self.verified = true
                self.consecutiveMatches = 0
            }
            else {
                if (response.dataReadyForUse == false) {
                    self.invalidateDevice(data)
                }
                else {
                    if (self.uniqueIdentifier != response.uniqueIdentifier) {
                        if (response.validation != 0 && response.opCode == 5) {
                            if (response.validation == 0xFA && response.dataType != 1) { // datatype 1 is the error packet
                                self.addValidMeasurement(response)
                            }
                            else if (response.validation != 0xFA && response.dataType != 1) {// datatype 1 is the error packet
                                self.invalidateDevice(data)
                            }
                        }
                        else if (response.validation != 0 && response.opCode == 3) {
                            if (response.validation == 0xFA && response.dataType != 1) { // datatype 1 is the error packet
                                self.addValidMeasurement(response)
                            }
                            else if (response.validation != 0xFA && response.dataType != 1) { // datatype 1 is the error packet
                                self.invalidateDevice(data)
                            }
                        }
                        else {
                            if (response.stateOfExternalCrownstone == false) {
                                if (response.crownstoneId == self.crownstoneId) {
                                    self.addValidMeasurement(response)
                                }
                                else {
                                    self.invalidateDevice(data)
                                }
                            }
                        }
                    }
                }
            }
            self.uniqueIdentifier = response.uniqueIdentifier
        }
        else {
            self.invalidateDevice(data)
        }
    }
    
    func addValidMeasurement(_ response: ScanResponsePacket) {
        if (self.consecutiveMatches >= AMOUNT_OF_REQUIRED_MATCHES) {
            self.verified = true
            self.consecutiveMatches = 0
        }
        else {
            self.consecutiveMatches += 1
        }
        
        self.crownstoneId = response.crownstoneId
    }
    
    func invalidateDevice(_ data: ScanResponsePacket?) {
        if let response = data {
            if (response.stateOfExternalCrownstone == false) {
                self.crownstoneId = response.crownstoneId
            }
        }
        
        self.consecutiveMatches = 0
        self.verified = false;
    }
    
    func calculateRssiAverage() {
        var count = 0
        var total : Double = 0
        for (_, rssi) in self.rssiHistory {
            total = total + Double(rssi)
            count += 1
        }
        self.avgRssi = total/Double(count);
    }
}
