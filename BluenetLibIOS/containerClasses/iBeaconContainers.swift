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

open class iBeaconContainer {
    var UUID : Foundation.UUID;
    var collectionId = ""
    var region : CLBeaconRegion
    var major  : CLBeaconMajorValue?
    var minor  : CLBeaconMinorValue?
    
    public init(collectionId: String, uuid: String) {
        self.UUID = Foundation.UUID(uuidString : uuid)!
        self.collectionId = collectionId
        self.region = CLBeaconRegion(proximityUUID: self.UUID, identifier: collectionId)
    }
    public init(collectionId: String, uuid: String, major: NSNumber) {
        self.UUID = Foundation.UUID(uuidString : uuid)!
        self.collectionId = collectionId
        self.major = major.uint16Value
        self.region = CLBeaconRegion(proximityUUID: self.UUID, major: self.major!, identifier: collectionId)
    }
    public init(collectionId: String, uuid: String, major: NSNumber, minor: NSNumber) {
        self.UUID = Foundation.UUID(uuidString : uuid)!
        self.collectionId = collectionId
        self.major = major.uint16Value
        self.minor = minor.uint16Value
        self.region = CLBeaconRegion(proximityUUID: self.UUID, major: self.major!, minor: self.minor!, identifier: collectionId)
    }
}

open class iBeaconPacket: iBeaconPacketProtocol {
    open var uuid : String
    open var major: NSNumber
    open var minor: NSNumber
    open var rssi : NSNumber
    open var distance : NSNumber
    open var idString: String
    open var collectionId: String
    
    init(uuid: String, major: NSNumber, minor: NSNumber, distance: NSNumber, rssi: NSNumber, collectionId: String) {
        self.uuid = uuid
        self.major = major
        self.minor = minor
        self.rssi = rssi
        self.distance = distance
        self.collectionId = collectionId
        
        // we claim that the uuid, major and minor combination is unique.
        self.idString = uuid + ".Maj:" + String(describing: major) + ".Min:" + String(describing: minor)
    }
    
    open func getJSON() -> JSON {
        var dataDict = [String : Any]()
        dataDict["id"]    = self.idString
        dataDict["uuid"]  = self.uuid
        dataDict["major"] = self.major
        dataDict["minor"] = self.minor
        dataDict["distance"]  = self.distance
        dataDict["rssi"]  = self.rssi
        dataDict["collectionId"]  = self.collectionId
        
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
            "collectionId" : self.collectionId,
        ]
        
        return returnDict as NSDictionary
    }
    
}
