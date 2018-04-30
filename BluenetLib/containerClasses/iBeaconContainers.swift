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
import BluenetShared

open class iBeaconContainer {
    var UUID : Foundation.UUID;
    var referenceId = ""
    var region : CLBeaconRegion
    var major  : CLBeaconMajorValue?
    var minor  : CLBeaconMinorValue?
    
    public init(referenceId: String, uuid: String) {
        self.UUID = Foundation.UUID(uuidString : uuid)!
        self.referenceId = referenceId
        self.region = CLBeaconRegion(proximityUUID: self.UUID, identifier: referenceId)
    }
    public init(referenceId: String, uuid: String, major: NSNumber) {
        self.UUID = Foundation.UUID(uuidString : uuid)!
        self.referenceId = referenceId
        self.major = major.uint16Value
        self.region = CLBeaconRegion(proximityUUID: self.UUID, major: self.major!, identifier: referenceId)
    }
    public init(referenceId: String, uuid: String, major: NSNumber, minor: NSNumber) {
        self.UUID = Foundation.UUID(uuidString : uuid)!
        self.referenceId = referenceId
        self.major = major.uint16Value
        self.minor = minor.uint16Value
        self.region = CLBeaconRegion(proximityUUID: self.UUID, major: self.major!, minor: self.minor!, identifier: referenceId)
    }
}

open class iBeaconPacket: iBeaconPacketProtocol {
    open var uuid : String
    open var major: NSNumber
    open var minor: NSNumber
    open var rssi : NSNumber
    open var distance : NSNumber
    open var idString: String
    open var referenceId: String
    
    init(uuid: String, major: NSNumber, minor: NSNumber, distance: NSNumber, rssi: NSNumber, referenceId: String) {
        self.uuid = uuid
        self.major = major
        self.minor = minor
        self.rssi = rssi
        self.distance = distance
        self.referenceId = referenceId
        
        // we claim that the uuid, major and minor combination is unique.
        self.idString = uuid + "_Maj:" + String(describing: major) + "_Min:" + String(describing: minor)
    }
    
    open func getJSON() -> JSON {
        var dataDict = [String : Any]()
        dataDict["id"]    = self.idString
        dataDict["uuid"]  = self.uuid
        dataDict["major"] = self.major
        dataDict["minor"] = self.minor
        dataDict["distance"]  = self.distance
        dataDict["rssi"]  = self.rssi
        dataDict["referenceId"]  = self.referenceId
        
        return JSON(dataDict)
    }
    
    open func stringify() -> String {
        return JSONUtils.stringify(self.getJSON())
    }
    
    open func getDictionary() -> NSDictionary {
        let returnDict : [String: Any] = [
            "id" : self.idString,
            "uuid" : self.uuid,
            "major" : self.major,
            "minor" : self.minor,
            "rssi" : self.rssi,
            "distance" : self.distance,
            "referenceId" : self.referenceId,
        ]
        
        return returnDict as NSDictionary
    }
    
}
