//
//  NearestItemContainer.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 28/08/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation

struct NearInformation {
    var name: String
    var handle: String
    var rssi: Int
    var updatedAt: Double
}

public class NearestItemContainer {
    var items = [String: NearInformation]()
    
    // config
    let timeout : Double = 20 //seconds

    init() {}
    
    public func load(name: String, handle:String, rssi: Int) {
        let currentTime = Date().timeIntervalSince1970
        // sometimes rssi can be 0 or 127, this is an invalid data point.
        if rssi < 0 {
            if self.items[handle] != nil {
                self.items[handle]!.updatedAt = currentTime
                self.items[handle]!.rssi = rssi
                self.items[handle]!.name = name
            }
            else {
                self.items[handle] = NearInformation(name: name, handle: handle, rssi: rssi, updatedAt: currentTime)
            }
        }
        
        self.removeExpired(currentTime: currentTime)
    }
    
    public func removeItem(handle: String) {
        if self.items[handle] != nil {
            self.items.removeValue(forKey: handle)
        }
    }
    
    public func getNearestItem(setupMode: Bool, dfuMode: Bool) -> NearestItem? {
        let nearestRSSI = -1000
        var nearestInfo : NearInformation? = nil
        for (_ , nearInfo) in self.items {
            if (nearInfo.rssi > nearestRSSI) {
                nearestInfo = nearInfo
            }
        }
        if (nearestInfo != nil) {
            // nearest elements in here (setup and dfu) are always considered verified
            return NearestItem(nearInfo: nearestInfo!, setupMode: setupMode, dfuMode: dfuMode, verified: true)
        }
        
        return nil
    }
    
    func removeExpired(currentTime: Double) {
        for (handle, nearInfo) in self.items {
            if currentTime - nearInfo.updatedAt > self.timeout {
                self.items.removeValue(forKey: handle)
            }
        }
    }
}
