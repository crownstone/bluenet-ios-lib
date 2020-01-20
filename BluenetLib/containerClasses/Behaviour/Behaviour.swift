//
//  Behaviour.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 22/10/2019.
//  Copyright © 2019 Alex de Mulder. All rights reserved.
//

import Foundation
import SwiftyJSON


public enum BehaviourType : UInt8 {
    case behaviour  = 0
    case twilight   = 1
    case smartTimer = 2
}


public enum BehaviourTimeType : UInt8 {
    case afterMidnight   = 0
    case afterSunrise    = 1
    case afterSunset     = 2
}


public enum BehaviourPresenceType : UInt8 {
    case ignorePresence   = 0
    case somoneInLocation = 1
    case nobodyInLocation = 2
    case someoneInSphere  = 3
    case nobodyInSphere   = 4
}


struct BehaviourTimeContainer {
    var from  : BehaviourTime
    var until : BehaviourTime
}


struct BehaviourEndCondition {
    var presence: BehaviourPresence
}



public class Behaviour {
    var profileIndex : UInt8!
    var type         : BehaviourType!
    var activeDays   : ActiveDays!
    var intensity    : UInt8!
    var from         : BehaviourTime!
    var until        : BehaviourTime!
    var presence     : BehaviourPresence? = nil
    var endCondition : BehaviourEndCondition? = nil
    
    var valid = true
    
    public var indexOnCrownstone : UInt8?
    
   
    init() {
        self.valid = false
    }
    /**
     This contains all required information for at least a Twlight behaviour.
     */
    convenience init(profileIndex: UInt8, type: BehaviourType, intensity: UInt8, activeDays: ActiveDays, time: BehaviourTimeContainer) {
        self.init()
        self.profileIndex = profileIndex
        self.type = type
        self.intensity = max(0,min(100, intensity))
        self.activeDays = activeDays
        self.from = time.from
        self.until = time.until
        self.valid = true
    }
    
    /**
     Adding presence for a normal behaviour
     */
    convenience init(profileIndex: UInt8, type: BehaviourType, intensity: UInt8, activeDays: ActiveDays, time: BehaviourTimeContainer, presence: BehaviourPresence) {
        self.init(profileIndex: profileIndex, type: type, intensity: intensity, activeDays: activeDays, time: time)
        self.presence = presence
    }

    /**
     Add an end condition for a smart timer
     */
    convenience init(profileIndex: UInt8, type: BehaviourType, intensity: UInt8, activeDays: ActiveDays, time: BehaviourTimeContainer, endCondition: BehaviourEndCondition) {
        self.init(profileIndex: profileIndex, type: type, intensity: intensity, activeDays: activeDays, time: time)
        self.endCondition = endCondition
    }

    /**
     Add presence AND an endcondition
     */
    convenience init(profileIndex: UInt8, type: BehaviourType, intensity: UInt8, activeDays: ActiveDays, time: BehaviourTimeContainer, presence: BehaviourPresence, endCondition: BehaviourEndCondition) {
        self.init(profileIndex: profileIndex, type: type, intensity: intensity, activeDays: activeDays, time:time, presence: presence)
        self.endCondition = endCondition
    }
    
    /**
            The payload is made up from
     - BehaviourType            1B
     - Intensity                       1B
     - profileIndex                  1B
     - ActiveDays                   1B
     - From                             5B
     - Until                              5B
     
     - Presence                       13B      --> for Switch Behaviour and Smart Timer
     - End Condition                17B      --> for Smart Timer
     */
    init(data: [UInt8]) {
        if data.count >= 14 {
            let type = BehaviourType.init(rawValue: data[0])
            if type == nil {
                self.valid = false
                return
            }
            
            self.type         = type
            self.intensity    = data[1]
            self.profileIndex = data[2]
            self.activeDays = ActiveDays(data: data[3])
            self.from  = BehaviourTime(data: Array(data[4...8]))  // 4 5 6 7 8
            self.until = BehaviourTime(data: Array(data[9...13])) // 9 10 11 12 13
            
            if self.from.valid == false || self.until.valid == false {
                self.valid = false
                return
            }
        }
        
        if self.type == .behaviour {
            if data.count >= 14+13 {
                self.presence = BehaviourPresence(data: Array(data[14...26])) // 14 15 16 17 18 19 20 21 22 23 24 25 26
                if self.presence!.valid == false {
                    self.valid = false
                    return
                }
            }
            else {
                self.valid = false
                return
            }
        }
        
        if self.type == .smartTimer {
            if data.count >= 14+13+17 {
                let presence = BehaviourPresence(data: Array(data[27...39]))
                if presence.valid == false {
                    self.valid = false
                    return
                }
        
                self.endCondition = BehaviourEndCondition(presence: presence)
            }
            else {
                self.valid = false
                return
            }
        }
    }
    
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        
        arr.append(self.type.rawValue)
        arr.append(self.intensity)
        arr.append(self.profileIndex)
        
        arr.append(self.activeDays.getMask())
        
        arr += self.from.getPacket()
        arr += self.until.getPacket()
        
        if self.presence != nil {
            arr += self.presence!.getPacket()
        }
        
        if self.endCondition != nil {
            arr += self.endCondition!.presence.getPacket()
        }

        return arr
    }
    
    func getPaddedPacket() -> [UInt8] {
        var packet = self.getPacket()
        if packet.count % 2 != 0 {
            packet.append(0)
        }
        return packet
    }
    
    func getHash() -> UInt32 {
        return fletcher32(self.getPaddedPacket())
    }
    
    public func getJSON(dayStartTimeSecondsSinceMidnight: UInt32 ) -> JSON {
        return JSON(self.getDictionary(dayStartTimeSecondsSinceMidnight: dayStartTimeSecondsSinceMidnight))
   }
    
    public func getDictionary(dayStartTimeSecondsSinceMidnight : UInt32) -> NSDictionary {
        var typeString = "BEHAVIOUR";
        if self.type == .twilight {
            typeString = "TWILIGHT"
        }
        
        
        var dataDictionary = [String: Any]()
        if self.type == .twilight {
            dataDictionary["action"] = ["type": "DIM_WHEN_TURNED_ON", "data": self.intensity]
            dataDictionary["time"] = self.getTimeDictionary(dayStartTimeSecondsSinceMidnight: dayStartTimeSecondsSinceMidnight)
        }
        else {
            // behaviour and smart timer have the same format
            dataDictionary["action"] = ["type": "BE_ON", "data": self.intensity]
            dataDictionary["time"] = self.getTimeDictionary(dayStartTimeSecondsSinceMidnight: dayStartTimeSecondsSinceMidnight)
            
            if let presence = self.presence {
                dataDictionary["presence"] = presence.getDictionary()
            }
            
            if let endCondition = self.endCondition {
                var endConditionDictionary = [String: Any]()
                endConditionDictionary["type"] = "PRESENCE_AFTER"
                endConditionDictionary["presence"] = endCondition.presence.getDictionary(includeDelay: false)
                
                dataDictionary["endCondition"] = endConditionDictionary
            }
        }
    
        var returnDict : [String: Any] = [
            "type"           : typeString,
            "data"           : dataDictionary,
            "activeDays"     : self.activeDays.getDictionary()
        ]
        
        returnDict["idOnCrownstone"] = index
        
        
        returnDict["profileIndex"] = self.profileIndex
        
        return returnDict as NSDictionary
    }
    
    func getTimeDictionary(dayStartTimeSecondsSinceMidnight : UInt32) -> NSDictionary {
        var returnDict = [String: Any]()
        
        // check if always
        if self.from.type == .afterMidnight && self.from.offset == dayStartTimeSecondsSinceMidnight && self.until.type == .afterMidnight && self.until.offset == dayStartTimeSecondsSinceMidnight {
            returnDict["type"] = "ALL_DAY"
            return returnDict as NSDictionary
        }
        
        // its not always! construct the from and to parts.
        returnDict["type"] = "RANGE"
        returnDict["from"] = self.from.getDictionary()
        returnDict["to"] = self.until.getDictionary()
        
        return returnDict as NSDictionary
    }
}


public class BehaviourTime {
    var type : BehaviourTimeType!
    var offset : Int32!
    var valid = true
    
    init(hours: NSNumber, minutes: NSNumber) {
        self.type = .afterMidnight
        self.offset = 3600*hours.int32Value + 60*minutes.int32Value
    }
    
    init(type: BehaviourTimeType, offset: UInt32) {
        self.type = type
        self.offset = Conversion.uint32_to_int32(offset)
    }
    
    init(type: BehaviourTimeType, offset: Int32) {
        self.type = type
        self.offset = offset
    }
    
    init(data : [UInt8]) {
        if (data.count != 5) {
            self.valid = false
            return
        }
        
        let type = BehaviourTimeType(rawValue: data[0])
        if type == nil {
            self.valid = false
            return
        }
        
        self.type = type!
        self.offset = Conversion.uint32_to_int32(Conversion.uint8_array_to_uint32(Array(data[1...4]))) // 1 2 3 4
        self.valid = true
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        
        arr.append(self.type.rawValue)
        arr += Conversion.uint32_to_uint8_array(Conversion.int32_to_uint32(self.offset))
        
        return arr
    }
    
    func getDictionary() -> NSDictionary {
        var returnDict = [String: Any]()
        
        if (self.type == .afterSunset) {
            returnDict["type"] = "SUNSET"
            returnDict["offsetMinutes"] = self.offset/60
        }
        else if (self.type == .afterSunrise) {
            returnDict["type"] = "SUNRISE"
            returnDict["offsetMinutes"] = self.offset/60
        }
        else {
            returnDict["type"] = "CLOCK"
            returnDict["data"] = ["hours": (self.offset - self.offset % 3600)/3600, "minutes": (self.offset % 3600) / 60]
        }
        
        return returnDict as NSDictionary
    }
}


public class BehaviourPresence {
    var type : BehaviourPresenceType!
    var locationIds : [UInt8]!
    var delayInSeconds : UInt32! // seconds
    var valid = true
    
    init() {
        self.type = .ignorePresence
        self.locationIds = []
        self.delayInSeconds = 0
    }
    
    
    init(type: BehaviourPresenceType, delayInSeconds: UInt32 = 300) {
        self.type = type
        self.locationIds = []
        self.delayInSeconds = delayInSeconds
    }
    
    init(type: BehaviourPresenceType, locationIds: [UInt8], delayInSeconds: UInt32 = 300) {
        self.type = type
        self.locationIds = locationIds
        self.delayInSeconds = delayInSeconds
    }

    init(type: BehaviourPresenceType, locationIds: [NSNumber], delayInSeconds: UInt32 = 300) {
        self.type = type
        self.locationIds = []
        for locationId in locationIds {
            self.locationIds.append(locationId.uint8Value)
        }
        self.delayInSeconds = delayInSeconds
    }
    
    init(data: [UInt8]) {
        if (data.count != 13) {
            self.valid = false
            return
        }
        
        let type = BehaviourPresenceType(rawValue: data[0])
        if type == nil {
            self.valid = false
            return
        }
        
        self.type = type!
        self.locationIds = self.unpackMask(Conversion.uint8_array_to_uint64(Array(data[1...8])))
        self.delayInSeconds = Conversion.uint8_array_to_uint32(Array(data[9...12]))
    }
    
    func getMask(_ locationIds : [UInt8]) ->  UInt64 {
        var result : UInt64 = 0
        let bit : UInt64 = 1
        for locationId in locationIds {
            if (locationId < 64) {
                result = result | bit << locationId
            }
        }
        return result
    }
    
    func unpackMask(_ mask: UInt64) -> [UInt8] {
        var result = [UInt8]()
        let bit : UInt64 = 1
        for i in 0...63 {
            if (mask >> i & bit) == 1 {
                result.append(UInt8(i))
            }
        }
        return result
    }
    
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        
        arr.append(self.type.rawValue)
        arr += Conversion.uint64_to_uint8_array(self.getMask(self.locationIds))
        arr += Conversion.uint32_to_uint8_array(self.delayInSeconds)
        
        return arr
    }
    
    
    func getDictionary(includeDelay: Bool = true) -> NSDictionary {
        var returnDict = [String: Any]()
        
        
        if (self.type == .ignorePresence) {
            returnDict["type"] = "IGNORE"
        }
        else if (self.type == .somoneInLocation) {
            returnDict["type"] = "SOMEBODY"
            returnDict["data"] = ["type":"LOCATION", "locationIds": self.locationIds]
        }
        else if (self.type == .someoneInSphere) {
            returnDict["type"] = "SOMEBODY"
            returnDict["data"] = ["type":"SPHERE"]
        }
        else if (self.type == .nobodyInLocation) {
            returnDict["type"] = "NOBODY"
            returnDict["data"] = ["type":"LOCATION", "locationIds": self.locationIds]
        }
        else if (self.type == .nobodyInSphere) {
            returnDict["type"] = "NOBODY"
            returnDict["data"] = ["type":"SPHERE"]
        }
        
        if (includeDelay && self.type != .ignorePresence) {
            returnDict["delay"] = self.delayInSeconds
        }
       

        return returnDict as NSDictionary
    }
}

public class ActiveDays {
    public var Monday    = false
    public var Tuesday   = false
    public var Wednesday = false
    public var Thursday  = false
    public var Friday    = false
    public var Saturday  = false
    public var Sunday    = false
    
    init() {}
    
    init(data: UInt8) {
        self.Sunday    = (data >> 0) & 0x01 == 1
        self.Monday    = (data >> 1) & 0x01 == 1
        self.Tuesday   = (data >> 2) & 0x01 == 1
        self.Wednesday = (data >> 3) & 0x01 == 1
        self.Thursday  = (data >> 4) & 0x01 == 1
        self.Friday    = (data >> 5) & 0x01 == 1
        self.Saturday  = (data >> 6) & 0x01 == 1
    }
    
    public func getMask() -> UInt8 {
        var mask : UInt8 = 0
        
        // bits:
        let MondayBit    : UInt8 = Monday    ? 1 : 0
        let TuesdayBit   : UInt8 = Tuesday   ? 1 : 0
        let WednesdayBit : UInt8 = Wednesday ? 1 : 0
        let ThursdayBit  : UInt8 = Thursday  ? 1 : 0
        let FridayBit    : UInt8 = Friday    ? 1 : 0
        let SaturdayBit  : UInt8 = Saturday  ? 1 : 0
        let SundayBit    : UInt8 = Sunday    ? 1 : 0
        
    
        // configure mask
        mask = mask | SundayBit    << 0
        mask = mask | MondayBit    << 1
        mask = mask | TuesdayBit   << 2
        mask = mask | WednesdayBit << 3
        mask = mask | ThursdayBit  << 4
        mask = mask | FridayBit    << 5
        mask = mask | SaturdayBit  << 6
        
        return mask
    }
    
    public func getDictionary() -> NSDictionary {
        let returnDict : [String: Any] = [
            "Sun" : self.Sunday,
            "Mon" : self.Monday,
            "Tue" : self.Tuesday,
            "Wed" : self.Wednesday,
            "Thu" : self.Thursday,
            "Fri" : self.Friday,
            "Sat" : self.Saturday,
        ]

        return returnDict as NSDictionary
    }
}

