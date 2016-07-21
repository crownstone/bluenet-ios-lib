//
//  AvailableDevice.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 17/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

public class AvailableDevice {
    var rssiHistory = [Double: Int]()
    var rssi : Int!
    var name : String?
    var uuid : String
    var lastUpdate : Double = 0
    var cleanupCallback : () -> Void
    var avgRssi : Double!
    
    // config
    let timeout : Double = 5 //seconds
    let rssiTimeout : Double = 2 //seconds
    
    init(_ data: Advertisement, _ cleanupCallback: () -> Void) {
        self.name = data.name
        self.uuid = data.uuid
        self.cleanupCallback = cleanupCallback
        self.avgRssi = data.rssi.doubleValue
        self.update(data)
    }
    
    func checkTimeout(referenceTime : Double) {
        // if they are equal, no update has happened since the scheduling of this check.
        if (self.lastUpdate == referenceTime) {
            self.cleanupCallback()
        }
    }
    
    func clearRSSI(referenceTime : Double) {
        self.rssiHistory.removeValueForKey(referenceTime)
        self.calculateRssiAverage()
    }
    
    func update(data: Advertisement) {
        self.rssi = data.rssi.integerValue
        self.lastUpdate = NSDate().timeIntervalSince1970
        self.rssiHistory[self.lastUpdate] = self.rssi;
        self.calculateRssiAverage()
        delay(self.timeout, {_ in self.checkTimeout(self.lastUpdate)});
        delay(self.rssiTimeout, {_ in self.clearRSSI(self.lastUpdate)});
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