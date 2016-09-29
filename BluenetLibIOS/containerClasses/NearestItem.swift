//
//  NearestItem.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 02/09/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import SwiftyJSON

public class NearestItem {
    var handle : String = ""
    var rssi : Int = 0
    var setupMode : Bool = false
    
    init(handle:String, rssi: Int, setupMode: Bool) {
        self.handle = handle;
        self.rssi = rssi
        self.setupMode = setupMode
    }
    
    public func getJSON() -> JSON {
        var dataDict = [String : AnyObject]()
        dataDict["handle"] = self.handle
        dataDict["rssi"] = self.rssi
        dataDict["setupMode"] = self.setupMode
        
        var dataJSON = JSON(dataDict)
        return dataJSON
    }
    
    public func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
    public func getDictionary() -> NSDictionary {
        var returnDict : [String: AnyObject] = [
            "handle" : self.handle,
            "rssi" : self.rssi,
            "setupMode" : self.setupMode
        ]
        
        return returnDict
    }
}
