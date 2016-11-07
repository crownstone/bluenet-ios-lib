//
//  Fingerprint.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 17/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import SwiftyJSON

open class Fingerprint {
    open var data = [[String:NSNumber]]()
    
    public init() {}
    public init(stringifiedData: String) {
        let jsonData = JSON.parse(stringifiedData)
        if let arr = jsonData.arrayObject {
            for possibleDict in arr {
                if let dict = possibleDict as? [String: NSNumber] {
                    data.append(dict)
                }
            }
        }
    }
    
    func collect(_ ibeaconData: [iBeaconPacket]) {
        var returnDict = [String: NSNumber]()
        
        for point in ibeaconData {
            returnDict[point.idString] = point.rssi
        }
        returnDict["timestamp"] = NSNumber(value: NSDate().timeIntervalSince1970)
        
        data.append(returnDict);
    }
    
    open func getJSON() -> JSON {
        return JSON(self.data)
    }
    
    open func stringify() -> String {
        return JSONUtils.stringify(JSON(self.data))
    }
}
