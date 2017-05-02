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
    var name : String = ""
    var handle : String = ""
    var rssi : Int = 0
    var setupMode : Bool = false
    var dfuMode : Bool = false
    
    init(name: String, handle:String, rssi: Int, setupMode: Bool, dfuMode: Bool) {
        self.name = name
        self.handle = handle;
        self.rssi = rssi
        self.setupMode = setupMode
        self.dfuMode = dfuMode
    }
    
    convenience init(name: String, handle:String, rssi: Int, setupMode: Bool) {
        self.init(name: name, handle: handle, rssi: rssi, setupMode: setupMode, dfuMode: false)
    }
    
    convenience init(name: String, handle:String, rssi: Int, dfuMode: Bool) {
        self.init(name: name, handle: handle, rssi: rssi, setupMode: false, dfuMode: dfuMode)
    }
    
    open func getJSON() -> JSON {
        var dataDict = [String : Any]()
        dataDict["name"] = self.name
        dataDict["handle"] = self.handle
        dataDict["rssi"] = self.rssi
        dataDict["setupMode"] = self.setupMode
        dataDict["dfuMode"] = self.dfuMode
        
        let dataJSON = JSON(dataDict)
        return dataJSON
    }
    
    open func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
    open func getDictionary() -> NSDictionary {
        let returnDict : [String: Any] = [
            "name": self.name,
            "handle" : self.handle,
            "rssi" : self.rssi,
            "setupMode" : self.setupMode,
            "dfuMode" : self.dfuMode
        ]
        
        return returnDict as NSDictionary
    }
}
