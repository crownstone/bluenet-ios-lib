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
    open var data = [String: [NSNumber]]()
    
    public init() {}
    public init(stringifiedData: String) {
        let jsonData = JSON.parse(stringifiedData)
        if let dictData = jsonData.dictionaryObject {
            for (key, data) in dictData {
                if let numArray = data as? [NSNumber] {
                    self.data[key] = numArray
                }
            }
        }
    }
    
    func collect(_ ibeaconData: [iBeaconPacket]) {
        for point in ibeaconData {
            if (data.index(forKey: point.idString) == nil) {
                data[point.idString] = [NSNumber]()
            }
            
            data[point.idString]!.append(point.rssi)
        }
    }
    
    open func getJSON() -> JSON {
        return JSON(self.data)
    }
    
    open func stringify() -> String {
        return JSONUtils.stringify(JSON(self.data))
    }
}
