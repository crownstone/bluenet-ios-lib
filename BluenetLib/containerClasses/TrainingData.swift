//
//  TrainingData.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 17/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import SwiftyJSON

open class TrainingData {
    open var data = [[String: Any]]()
    
    public init() {}
    public init(stringifiedData: String) {
        let jsonData = JSON(parseJSON: stringifiedData)
        if let arr = jsonData.arrayObject {
            for possibleDict in arr {
                if let dict = possibleDict as? [String: Any] {
                    data.append(dict)
                }
            }
        }
    }
    
    func collect(_ ibeaconData: [iBeaconPacket]) {
        var dataDict = [String: Any]()
        
        var devicesDict = [String: NSNumber]()
        for point in ibeaconData {
            devicesDict[point.idString] = point.rssi
        }
        dataDict["devices"] = devicesDict
        dataDict["timestamp"] = NSNumber(value: NSDate().timeIntervalSince1970)
        
        data.append(dataDict);
    }
    
    open func getJSON() -> JSON {
        return JSON(self.data)
    }
    
    open func stringify() -> String {
        return JSONUtils.stringify(JSON(self.data))
    }
}
