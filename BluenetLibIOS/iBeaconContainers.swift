//
//  iBeaconPacket.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 17/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreLocation
import SwiftyJSON

public class iBeaconContainer {
    var UUID : NSUUID;
    var groupId = ""
    var region : CLBeaconRegion;
    
    public init(groupId: String, uuid: String) {
        self.UUID = NSUUID(UUIDString : uuid)!;
        self.groupId = groupId;
        self.region = CLBeaconRegion(proximityUUID: self.UUID, identifier: groupId);
    }
}

public class iBeaconPacket {
    public var uuid : String
    public var major: NSNumber
    public var minor: NSNumber
    public var rssi : NSNumber
    public var idString: String
    
    init(uuid: String, major: NSNumber, minor: NSNumber, rssi: NSNumber) {
        self.uuid = uuid
        self.major = major
        self.minor = minor
        self.rssi = rssi
        
        // we claim that the uuid, major and minor combination is unique.
        self.idString = uuid + ".Maj:" + String(major) + ".Min:" + String(minor)
    }
    
    public func getJSON() -> JSON {
        var dataDict = [String : AnyObject]()
        dataDict["id"]    = self.idString
        dataDict["uuid"]  = self.uuid
        dataDict["major"] = self.major
        dataDict["minor"] = self.minor
        dataDict["rssi"]  = self.rssi
        
        return JSON(dataDict)
    }
    
    public func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
}