//
//  NearestItem.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 02/09/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import SwiftyJSON

open class NearestItem {
    var handle : String = ""
    var rssi : Int = 0
    var setupMode : Bool = false
    
    init(handle:String, rssi: Int, setupMode: Bool) {
        self.handle = handle;
        self.rssi = rssi
        self.setupMode = setupMode
    }
    
    open func getJSON() -> JSON {
        var dataDict = [String : Any]()
        dataDict["handle"] = self.handle
        dataDict["rssi"] = self.rssi
        dataDict["setupMode"] = self.setupMode
        
        let dataJSON = JSON(dataDict)
        return dataJSON
    }
    
    open func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
    open func getDictionary() -> NSDictionary {
        let returnDict : [String: Any] = [
            "handle" : self.handle,
            "rssi" : self.rssi,
            "setupMode" : self.setupMode
        ]
        
        return returnDict as NSDictionary
    }
}
