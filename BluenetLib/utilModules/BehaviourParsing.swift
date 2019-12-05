//
//  BehaviourParsing.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 04/12/2019.
//  Copyright © 2019 Alex de Mulder. All rights reserved.
//

import Foundation

/**
 We will assume that there is a dictionary format which is used to provide the system with the behaviour data. We will throw an error on incorrect format. Otherwise we will parse it and return the Behaviour object.
 Expected format:
 
 {
    type: "BEHAVIOUR" | "TWILIGHT",
    data: {
        action: { data: number },
        time: TIME_PARSER_INPUT,
        presence: PRESENCE_PARSER_INPUT
        endCondition: ENDCONDITION_PARSER_INPUT
    },
    activeDays: {
      Mon: boolean,
      Tue: boolean,
      Wed: boolean,
      Thu: boolean,
      Fri: boolean,
      Sat: boolean,
      Sun: boolean
    },
    idOnCrownstone: NSNumber,
    profileIndex: NSNumber
 }
 
 */
public func BehaviourDictionaryParser(_ dict: NSDictionary, dayStartTimeSecondsSinceMidnight: UInt32) throws -> Behaviour {
    // optional variables
    let oProfileIndex   = dict["profileIndex"]   as? NSNumber
    let oType           = dict["type"]           as? String
    let oData           = dict["data"]           as? NSDictionary
    let oActiveDays     = dict["activeDays"]     as? NSDictionary
    let oIdOnCrownstone = dict["idOnCrownstone"] as? NSNumber
    
    guard let profileIndex = oProfileIndex else { throw BluenetError.PROFILE_INDEX_MISSING }
    guard let type         = oType         else { throw BluenetError.TYPE_MISSING }
    guard let data         = oData         else { throw BluenetError.DATA_MISSING }
    guard let activeDays   = oActiveDays   else { throw BluenetError.ACTIVE_DAYS_MISSING }
    
    var behaviourType : BehaviourType = .behaviour
    if type == "BEHAVIOUR" {
        behaviourType = .behaviour
    }
    else if type == "TWILIGHT" {
        behaviourType = .twilight
    }
    
    // optional variables
    let oAction       = data["action"]       as? NSDictionary
    let oTime         = data["time"]         as? NSDictionary
    let oPresence     = data["presence"]     as? NSDictionary
    let oEndCondition = data["endCondition"] as? NSDictionary
    
    guard let actionDict = oAction else { throw BluenetError.BEHAVIOUR_ACTION_MISSING }
    guard let timeDict   = oTime   else { throw BluenetError.BEHAVIOUR_TIME_MISSING }
    
    let oIntensity = actionDict["data"] as? NSNumber
    
    guard let intensity = oIntensity else { throw BluenetError.BEHAVIOUR_INTENSITY_MISSING }
    
    let activeDayObject = try ActiveDayParser(activeDays)
    let timeObject      = try TimeParser(timeDict, dayStartTimeSecondsSinceMidnight: dayStartTimeSecondsSinceMidnight)
    
    let behaviour = Behaviour(
        profileIndex: profileIndex.uint8Value,
        type: behaviourType,
        intensity: intensity.doubleValue,
        activeDays: activeDayObject,
        time: timeObject
    )
    
    if let index = oIdOnCrownstone {
        behaviour.indexOnCrownstone = index.uint8Value
    }
    
    if let presence = oPresence {
        if behaviourType == .twilight {
            throw BluenetError.TWILIGHT_CANT_HAVE_PRESENCE
        }
        let presenceObject = try PresenceParser(presence)
        behaviour.presence = presenceObject
    }
    
    if let endCondition = oEndCondition {
        if behaviourType == .twilight {
            throw BluenetError.TWILIGHT_CANT_HAVE_END_CONDITION
        }
        let endConditionObject = try EndConditionParser(endCondition)
        behaviour.endCondition = endConditionObject
        behaviour.type = .smartTimer
    }
    
    return behaviour
}

/**
 There are a few possible formats. We will parse and validate
 */
func ActiveDayParser(_ dict: NSDictionary) throws -> ActiveDays {
    let Monday    = dict["Mon"] as? Bool
    let Tuesday   = dict["Tue"] as? Bool
    let Wednesday = dict["Wed"] as? Bool
    let Thursday  = dict["Thu"] as? Bool
    let Friday    = dict["Fri"] as? Bool
    let Saturday  = dict["Sat"] as? Bool
    let Sunday    = dict["Sun"] as? Bool
    
    let activeDays = ActiveDays()
    
    if (Monday != nil && Tuesday != nil && Wednesday != nil && Thursday != nil && Friday != nil && Saturday != nil && Sunday != nil) {
        activeDays.Monday    = Monday!
        activeDays.Tuesday   = Tuesday!
        activeDays.Wednesday = Wednesday!
        activeDays.Thursday  = Thursday!
        activeDays.Friday    = Friday!
        activeDays.Saturday  = Saturday!
        activeDays.Sunday    = Sunday!
        
        if (activeDays.getMask() == 0) {
            throw BluenetError.NO_ACTIVE_DAYS
        }
        
        return activeDays
    }
    else {
        throw BluenetError.ACTIVE_DAYS_INVALID
    }
}

/**
 There are a few possible formats. We will parse and validate
 */
func TimeParser(_ dict: NSDictionary, dayStartTimeSecondsSinceMidnight : UInt32) throws -> BehaviourTimeContainer {
    let oType = dict["type"] as? String
    
    guard let type = oType else { throw BluenetError.NO_TIME_TYPE }
    
    if (type == "ALL_DAY") {
        return BehaviourTimeContainer.init(
            from:  BehaviourTime(type: .afterMidnight, offset: dayStartTimeSecondsSinceMidnight),
            until: BehaviourTime(type: .afterMidnight, offset: dayStartTimeSecondsSinceMidnight)
        )
    }
    else if (type == "RANGE") {
        let oFrom = dict["from"] as? NSDictionary
        let oTo   = dict["to"]   as? NSDictionary
        
        guard let from = oFrom else { throw BluenetError.MISSING_FROM_TIME }
        guard let to   = oTo   else { throw BluenetError.MISSING_TO_TIME   }
        
        let oFromType = from["type"] as? String
        let oToType   = to["type"]   as? String
        
        guard let fromType = oFromType else { throw BluenetError.MISSING_FROM_TIME_TYPE }
        guard let toType   = oToType   else { throw BluenetError.MISSING_TO_TIME_TYPE   }
        
       
        
        var fromResult : BehaviourTime
        var toResult : BehaviourTime
        
        if (fromType == "CLOCK") {
            let oFromData = from["data"] as? NSDictionary
        
            guard let fromData = oFromData else { throw BluenetError.MISSING_FROM_TIME_DATA }
            
            let oHours   = fromData["hours"]   as? NSNumber
            let oMinutes = fromData["minutes"] as? NSNumber
            
            guard let hours   = oHours   else { throw BluenetError.INVALID_FROM_DATA }
            guard let minutes = oMinutes else { throw BluenetError.INVALID_FROM_DATA }
            
            fromResult = BehaviourTime(hours: hours, minutes: minutes)
        }
        else if (fromType == "SUNSET") {
            var offsetSeconds : Int32 = 0
            if let offsetMinutes = from["offsetMinutes"] as? NSNumber {
                offsetSeconds = 60*offsetMinutes.int32Value
            }
            fromResult = BehaviourTime(type: .afterSunset, offset: offsetSeconds)
        }
        else if (fromType == "SUNRISE") {
            var offsetSeconds : Int32 = 0
            if let offsetMinutes = from["offsetMinutes"] as? NSNumber {
                offsetSeconds = 60*offsetMinutes.int32Value
            }
            fromResult = BehaviourTime(type: .afterSunrise, offset: offsetSeconds)
        }
        else {
            throw BluenetError.INVALID_TIME_FROM_TYPE
        }
        
        
        if (toType == "CLOCK") {
            let oToData   = to["data"]   as? NSDictionary
            
            guard let toData   = oToData   else { throw BluenetError.MISSING_TO_TIME_DATA   }
            
            let oHours   = toData["hours"]   as? NSNumber
            let oMinutes = toData["minutes"] as? NSNumber
            
            guard let hours   = oHours   else { throw BluenetError.INVALID_TO_DATA }
            guard let minutes = oMinutes else { throw BluenetError.INVALID_TO_DATA }
            
            toResult = BehaviourTime(hours: hours, minutes: minutes)
        }
        else if (toType == "SUNSET") {
            var offsetSeconds : Int32 = 0
            if let offsetMinutes = to["offsetMinutes"] as? NSNumber {
                offsetSeconds = 60*offsetMinutes.int32Value
            }
            toResult = BehaviourTime(type: .afterSunset, offset: offsetSeconds)
        }
        else if (toType == "SUNRISE") {
            var offsetSeconds : Int32 = 0
            if let offsetMinutes = to["offsetMinutes"] as? NSNumber {
                offsetSeconds = 60*offsetMinutes.int32Value
            }
            toResult = BehaviourTime(type: .afterSunrise, offset: offsetSeconds)
        }
        else {
            throw BluenetError.INVALID_TIME_TO_TYPE
        }
        
        return BehaviourTimeContainer.init(from: fromResult, until: toResult)
    }
    else {
        throw BluenetError.INVALID_TIME_TYPE
    }
    
}

/**
 There are a few possible formats. We will parse and validate
 */
func PresenceParser(_ dict: NSDictionary) throws -> BehaviourPresence {
    let oType = dict["type"] as? String
    
    guard let type = oType else { throw BluenetError.NO_PRESENCE_TYPE }
    
    if (type == "IGNORE") {
        return BehaviourPresence()
    }
    else if (type == "SOMEBODY" || type == "NOBODY") {
        let oData  = dict["data"]  as? NSDictionary
        
        
        guard let data  = oData  else { throw BluenetError.NO_PRESENCE_DATA }
        
        let oDelay = dict["delay"] as? NSNumber
        guard let delayResult = oDelay else { throw BluenetError.NO_PRESENCE_DELAY }
        let delay = delayResult
    
        let oDataType = data["type"] as? String
        
        guard let dataType = oDataType else { throw BluenetError.NO_PRESENCE_DATA }
        
        if (dataType == "SPHERE") {
            if (type == "SOMEBODY") {
                return BehaviourPresence(type: .someoneInSphere, delayInSeconds: delay.uint32Value)
            }
            else {
                return BehaviourPresence(type: .nobodyInSphere, delayInSeconds: delay.uint32Value)
            }
        }
        else if (dataType == "LOCATION") {
            let oLocationIdArray = data["locationIds"] as? [NSNumber]
                   
            guard let locationIdArray = oLocationIdArray else { throw BluenetError.NO_PRESENCE_LOCATION_IDS }
                   
            if (type == "SOMEBODY") {
                return BehaviourPresence(type: .somoneInLocation, locationIds: locationIdArray, delayInSeconds: delay.uint32Value)
            }
            else {
                return BehaviourPresence(type: .nobodyInLocation, locationIds: locationIdArray, delayInSeconds: delay.uint32Value)
            }
        }
        else {
            throw BluenetError.NO_PRESENCE_DATA
        }
    }
    else {
        throw BluenetError.INVALID_PRESENCE_TYPE
    }
    
    
}

/**
 There are a few possible formats. We will parse and validate
 */
func EndConditionParser(_ dict: NSDictionary) throws -> BehaviourEndCondition {
    let oType     = dict["type"] as? String
    let oPresence = dict["presence"] as? NSDictionary
    
    guard let type = oType         else { throw BluenetError.NO_END_CONDITION_TYPE }
    guard let presence = oPresence else { throw BluenetError.NO_END_CONDITION_PRESENCE }
    
    let presenceObject = try PresenceParser(presence)
    
    return BehaviourEndCondition(presence:presenceObject)
}
