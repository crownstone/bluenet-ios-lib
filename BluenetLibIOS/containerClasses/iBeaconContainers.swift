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
    var referenceId = ""
    var region : CLBeaconRegion
    var major  : CLBeaconMajorValue?
    var minor  : CLBeaconMinorValue?
    
    public init(referenceId: String, uuid: String) {
        self.UUID = NSUUID(UUIDString : uuid)!
        self.referenceId = referenceId
        self.region = CLBeaconRegion(proximityUUID: self.UUID, identifier: referenceId)
    }
    public init(referenceId: String, uuid: String, major: NSNumber) {
        self.UUID = NSUUID(UUIDString : uuid)!
        self.referenceId = referenceId
        self.major = major.unsignedShortValue
        self.region = CLBeaconRegion(proximityUUID: self.UUID, major: self.major!, identifier: referenceId)
    }
    public init(referenceId: String, uuid: String, major: NSNumber, minor: NSNumber) {
        self.UUID = NSUUID(UUIDString : uuid)!
        self.referenceId = referenceId
        self.major = major.unsignedShortValue
        self.minor = minor.unsignedShortValue
        self.region = CLBeaconRegion(proximityUUID: self.UUID, major: self.major!, minor: self.minor!, identifier: referenceId)
    }
    
 
}

public class iBeaconPacket {
    public var uuid : String
    public var major: NSNumber
    public var minor: NSNumber
    public var rssi : NSNumber
    public var idString: String
    public var referenceId: String
    
    init(uuid: String, major: NSNumber, minor: NSNumber, rssi: NSNumber, referenceId: String) {
        self.uuid = uuid
        self.major = major
        self.minor = minor
        self.rssi = rssi
        self.referenceId = referenceId
        
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
        dataDict["referenceId"]  = self.referenceId
        
        return JSON(dataDict)
    }
    
    public func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
    public func getDictionary() -> NSDictionary {
        var returnDict : [String: AnyObject] = [
            "id" : self.idString,
            "uuid" : self.uuid,
            "major" : self.major,
            "minor" : self.minor,
            "rssi" : self.rssi,
            "referenceId" : self.referenceId,
        ]
        
        return returnDict
    }
    
}
