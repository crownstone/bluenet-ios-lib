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
}

public class CrownstoneContainer {
    var items = [String: CrownstoneSummary]()
    
    // config
    let timeout : Double = 20 //seconds
    
    var setupMode: Bool = false
    var dfuMode:   Bool = false
    
    init(setupMode: Bool, dfuMode: Bool) {
        self.setupMode = setupMode
        self.dfuMode   = dfuMode
    }
    
    public func load(name: String, handle:String, rssi: Int, validated: Bool) {
        let currentTime = Date().timeIntervalSince1970
        // sometimes rssi can be 0 or 127, this is an invalid data point.
        if rssi < 0 {
            if self.items[handle] != nil {
                self.items[handle]!.updatedAt = currentTime
                self.items[handle]!.rssi = rssi
                self.items[handle]!.name = name
                self.items[handle]!.validated = validated
            }
            else {
                self.items[handle] = CrownstoneSummary(name: name, handle: handle, rssi: rssi, updatedAt: currentTime, validated: validated)
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
        
        var nearestRSSI = -1000
        var nearStone : CrownstoneSummary? = nil
        for (_ , nearInfo) in self.items {
            if (nearInfo.rssi > nearestRSSI) {
                nearStone = nearInfo
                nearestRSSI = nearInfo.rssi
            }
        }
        if (nearStone != nil) {
            // nearest elements in here (setup and dfu) are always considered verified
            return NearestItem(nearStone: nearStone!, setupMode: self.setupMode, dfuMode: self.dfuMode)
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
