//
//  BluenetSettings.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 21/07/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

public struct LocationState {
    public var sphereUID    : UInt8 = 0
    public var locationId   : UInt8 = 0
    public var profileIndex : UInt8 = 0
    public var deviceToken  : UInt8 = 0
    public var referenceId  : String? = nil
    
    public init(sphereUID: UInt8, locationId: UInt8, profileIndex: UInt8 , deviceToken: UInt8, referenceId: String) {
        self.sphereUID     = sphereUID
        self.locationId    = locationId
        self.profileIndex  = profileIndex
        self.deviceToken   = deviceToken
        self.referenceId   = referenceId
    }
    
    public init() {
        
    }
}

public struct DevicePreferences {
    public var rssiOffset   : Int8 = 0
    public var tapToToggle  : Bool = false
    public var ignoreForBehaviour: Bool = false
    public var useTimeBasedNonce : Bool = false
    public var useBackgroundBroadcasts: Bool = false
    public var useBaseBroadcasts: Bool = false
    public var trackingNumber: UInt32 = 0
    
    public init(rssiOffset:Int8? = nil, tapToToggle:Bool? = nil, ignoreForBehaviour:Bool? = nil, useBackgroundBroadcasts:Bool? = nil, useBaseBroadcasts:Bool? = nil, trackingNumber: UInt32? = nil, useTimeBasedNonce: Bool? = nil) {
        if let rssiOffsetValue  = rssiOffset                            { self.rssiOffset              = rssiOffsetValue  }
        if let tapToToggleValue = tapToToggle                           { self.tapToToggle             = tapToToggleValue }
        if let ignoreForBehaviourValue = ignoreForBehaviour             { self.ignoreForBehaviour      = ignoreForBehaviourValue }
        if let useBackgroundBroadcastsValue = useBackgroundBroadcasts   { self.useBackgroundBroadcasts = useBackgroundBroadcastsValue }
        if let useBaseBroadcastsValue       = useBaseBroadcasts         { self.useBaseBroadcasts       = useBaseBroadcastsValue }
        if let trackingNumberValue          = trackingNumber            { self.trackingNumber          = trackingNumberValue }
        if let useTimeBasedNonceValue       = useTimeBasedNonce         { self.useTimeBasedNonce       = useTimeBasedNonceValue }
    }
}



public class BluenetSettings {
    public var encryptionEnabled = false

    public var keySets    = [String: KeySet]()
    public var keySetList = [KeySet]()
    
    var locationState = LocationState()
    var devicePreferences = DevicePreferences()
    
    var backgroundState = false
    
    public var sunriseSecondsSinceMidnight : UInt32? = nil
    public var sunsetSecondsSinceMidnight  : UInt32? = nil
    
    
    init() {
        self._checkBackgroundState()
    }
    
    public func loadKeySets(encryptionEnabled: Bool, keySets: [KeySet]) {
        self.encryptionEnabled = encryptionEnabled
        self.keySetList = keySets
        for keySet in keySets {
            self.keySets[keySet.referenceId] = keySet
        }
    }
    
    public func setLocationState(sphereUID: UInt8, locationId: UInt8, profileIndex: UInt8, deviceToken: UInt8, referenceId: String) {
        self.locationState.sphereUID = sphereUID
        self.locationState.locationId = locationId
        self.locationState.profileIndex = profileIndex
        self.locationState.deviceToken = deviceToken
        self.locationState.referenceId = referenceId
    }
    
    public func setDevicePreferences(rssiOffset: Int8, tapToToggle: Bool, ignoreForBehaviour: Bool, useBackgroundBroadcasts: Bool, useBaseBroadcasts: Bool, useTimeBasedNonce: Bool, trackingNumber: UInt32) {
        self.devicePreferences.rssiOffset = rssiOffset
        self.devicePreferences.tapToToggle = tapToToggle
        self.devicePreferences.ignoreForBehaviour = ignoreForBehaviour
        self.devicePreferences.useBackgroundBroadcasts = useBackgroundBroadcasts
        self.devicePreferences.useBaseBroadcasts = useBaseBroadcasts
        self.devicePreferences.trackingNumber = trackingNumber
        self.devicePreferences.useTimeBasedNonce = useTimeBasedNonce
    }
    
    
    public func setSunTimes(sunriseSecondsSinceMidnight: UInt32, sunsetSecondsSinceMidnight: UInt32) {
        self.sunriseSecondsSinceMidnight = sunriseSecondsSinceMidnight
        self.sunsetSecondsSinceMidnight  = sunsetSecondsSinceMidnight
    }
  
    
    public func keysAvailable(referenceId: String) -> Bool {      
        if keySets[referenceId] == nil {
            return false
        }
        
        return true
    }
    
    
    /**
     * This gets the admin key of the session reference keySet
     **/
    func getAdminKey(referenceId: String) -> [UInt8]? {
        if self.keySets[referenceId] != nil {
            return self.keySets[referenceId]!.adminKey
        }
        else {
            return nil
        }
    }

    /**
     * This gets the member key of the session reference keySet
     **/
    func getMemberKey(referenceId: String) -> [UInt8]? {
        if self.keySets[referenceId] != nil {
            return self.keySets[referenceId]!.memberKey
        }
        else {
            return nil
        }
    }

    /**
     * This gets the basic key of the session reference keySet
     **/
    func getBasicKey(referenceId: String) -> [UInt8]? {
        if self.keySets[referenceId] != nil {
            return self.keySets[referenceId]!.basicKey
        }
        else {
            return nil
        }
    }


    /**
     * This gets the basic key of the session reference keySet
     **/
    func getServiceDataKey(referenceId: String) -> [UInt8]? {
        if self.keySets[referenceId] != nil {
            return self.keySets[referenceId]!.serviceDataKey
        }
        else {
            return nil
        }
    }



    func getLocalizationKey(referenceId: String) -> [UInt8]? {
        if self.keySets[referenceId] != nil {
            return self.keySets[referenceId]!.localizationKey
        }
        else {
            return nil
        }
    }


    func getUserLevel(referenceId: String) -> UserLevel {
        if self.keySets[referenceId] == nil {
            return .unknown
        }

        let adminKey  = self.keySets[referenceId]?.adminKey
        let memberKey = self.keySets[referenceId]?.memberKey
        let basicKey  = self.keySets[referenceId]?.basicKey

        if (adminKey != nil && adminKey!.count == 16) {
            return .admin
        }
        else if (memberKey != nil && memberKey!.count == 16) {
            return .member
        }
        else if (basicKey != nil && basicKey!.count == 16) {
            return .basic
        }
        else {
            return .unknown
        }
    }
    
    func getKey(referenceId: String, userLevel: UserLevel) throws -> [UInt8]  {
        if userLevel == .unknown {
            throw BluenetError.COULD_NOT_ENCRYPT_KEYS_NOT_SET
        }
        if self.keySets[referenceId] == nil {
            throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY
        }
        
        var key : [UInt8]?
        switch (userLevel) {
        case .admin:
            key = self.keySets[referenceId]!.adminKey
        case .member:
            key = self.keySets[referenceId]!.memberKey
        case .basic:
            key = self.keySets[referenceId]!.basicKey
        default:
            throw BluenetError.INVALID_KEY_FOR_ENCRYPTION
        }
        
        if (key == nil) {
            throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY
        }
        
        if (key!.count != 16) {
            throw BluenetError.DO_NOT_HAVE_ENCRYPTION_KEY
        }
        
        return key!
    }
    
    
    func _checkBackgroundState() {
        #if os(iOS)
        if (Thread.isMainThread == true) {
            let state = UIApplication.shared.applicationState
            if state == .background {
                self.backgroundState = true
            }
            else {
                self.backgroundState = false
            }
        }
        else {
            DispatchQueue.main.sync{
                let state = UIApplication.shared.applicationState
                if state == .background {
                    self.backgroundState = true
                }
                else {
                    self.backgroundState = false
                }
            }
        }
        #endif
    }
}
