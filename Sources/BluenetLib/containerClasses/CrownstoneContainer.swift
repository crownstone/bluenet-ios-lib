//
//  CrownstoneContainer
//  BluenetLib
//
//  Created by Alex de Mulder on 28/08/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation

struct CrownstoneSummary {
    var name: String
    var handle: String
    var rssi: Int
    var updatedAt: Double
    var validated: Bool
    var setupMode: Bool
    var dfuMode: Bool
}

public class CrownstoneContainer {
    var items = [String: CrownstoneSummary]()
    
    // config
    let timeout : Double = 20 //seconds
    
    var lastRemoval : Double = 0
    
    var nearest : CrownstoneSummary? = nil
    
    
    public func load(name: String, handle:String, rssi: Int, validated: Bool, setupMode: Bool, dfuMode: Bool) {
        let currentTime = Date().timeIntervalSince1970
        // sometimes rssi can be 0 or 127, this is an invalid data point.
        if rssi < 0 {
            if self.items[handle] != nil {
                self.items[handle]!.updatedAt = currentTime
                self.items[handle]!.rssi = rssi
                self.items[handle]!.name = name
                self.items[handle]!.validated = validated
                self.items[handle]!.setupMode = setupMode
                self.items[handle]!.dfuMode = dfuMode
            }
            else {
                self.items[handle] = CrownstoneSummary(name: name, handle: handle, rssi: rssi, updatedAt: currentTime, validated: validated, setupMode: setupMode, dfuMode: dfuMode)
            }
            
            if self.nearest != nil {
                if self.nearest!.rssi < self.items[handle]!.rssi {
                    self.nearest = self.items[handle]
                }
                else if self.nearest!.handle == handle {
                    self.nearest = nil
                }
            }
            
        }
    }
    
    public func removeItem(handle: String) {
        if self.items[handle] != nil {
            self.items.removeValue(forKey: handle)
        }
    }
    
    public func getNearestItem() -> NearestItem? {
        let currentTime = Date().timeIntervalSince1970
        self.removeExpired(currentTime: currentTime)
        
        if self.nearest != nil {
            return NearestItem(nearStone: self.nearest!)
        }
        
        var nearestRSSI = -1000
        var nearStone : CrownstoneSummary? = nil
        for (_ , nearInfo) in self.items {
            if (nearInfo.rssi > nearestRSSI) {
                nearStone = nearInfo
                nearestRSSI = nearInfo.rssi
            }
        }
        if (nearStone != nil) {
            self.nearest = nearStone!
            
            // nearest elements in here (setup and dfu) are always considered verified
            return NearestItem(nearStone: nearStone!)
        }
        
        return nil
    }
    
    func removeExpired(currentTime: Double) {
        // only check this once every second at most
        if currentTime - self.lastRemoval < 1 {
            return
        }
        
        for (handle, nearInfo) in self.items {
            if currentTime - nearInfo.updatedAt > self.timeout {
                self.items.removeValue(forKey: handle)

                if self.nearest != nil {
                    if self.nearest!.handle == nearInfo.handle {
                        self.nearest = nil
                    }
                }
            }
        }
        
        self.lastRemoval = currentTime
    }
}
