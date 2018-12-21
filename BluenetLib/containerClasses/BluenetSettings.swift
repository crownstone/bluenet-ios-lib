//
//  BluenetSettings.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 21/07/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

public struct LocationState {
    public var sphereUID    : UInt8? = nil
    public var locationId   : UInt8? = nil
    public var profileIndex : UInt8? = nil
    public var referenceId  : String? = nil
    
    public init(sphereUID:UInt8? = nil,locationId:UInt8? = nil,profileIndex:UInt8? = nil,referenceId:String? = nil) {
        self.sphereUID = sphereUID
        self.locationId = locationId
        self.profileIndex = profileIndex
        self.referenceId = referenceId
    }
}


public class BluenetSettings {
    public var encryptionEnabled = false
    public var temporaryDisable = false
    
    public var sessionReferenceId : String? = nil

    public var keySets = [String: KeySet]()
    public var keySetList = [KeySet]()
    
    public var setupKey     : [UInt8]? = nil
    public var sessionNonce : [UInt8]? = nil
    
    public var userLevel : UserLevel = .unknown
    var locationState = LocationState()
    
    init() {}
    
    public func loadKeySets(encryptionEnabled: Bool, keySets: [KeySet]) {
        self.encryptionEnabled = encryptionEnabled
        self.keySetList = keySets
        for keySet in keySets {
            self.keySets[keySet.referenceId] = keySet
        }
    }
    
    public func setLocationState(sphereUID: UInt8, locationId: UInt8, profileIndex: UInt8, referenceId: String) {
        self.locationState.sphereUID = sphereUID
        self.locationState.locationId = locationId
        self.locationState.profileIndex = profileIndex
        self.locationState.referenceId = referenceId
    }
    
  
    
    public func setSessionId(referenceId: String) -> Bool {
        self.setupKey = nil
        self.sessionNonce = nil
        self.userLevel = .unknown
        
        if keySets[referenceId] == nil {
            return false
        }
        
        self.sessionReferenceId = referenceId
        self.detemineUserLevel()
        
        return true
    }
    
    
    /**
     * This gets the admin key of the session reference keySet
     **/
    func getAdminKey() -> [UInt8]? {
        if self._checkSessionId() {
            return keySets[self.sessionReferenceId!]!.adminKey
        }
        return nil
    }
    
    /**
     * This gets the member key of the session reference keySet
     **/
    func getMemberKey() -> [UInt8]? {
        if self._checkSessionId() {
            return keySets[self.sessionReferenceId!]!.memberKey
        }
        return nil
    }
    
    /**
     * This gets the guest key of the session reference keySet
     **/
    func getGuestKey() -> [UInt8]? {
        if self._checkSessionId() {
            return keySets[self.sessionReferenceId!]!.guestKey
        }
        return nil
    }
    
    
    func getGuestKey(referenceId: String) -> [UInt8]? {
        if self.keySets[referenceId] != nil {
            return self.keySets[referenceId]!.guestKey
        }
        else {
            return nil
        }
    }
    
    
    func _checkSessionId() -> Bool {
        if self.sessionReferenceId == nil {
            return false
        }
        
        if keySets[self.sessionReferenceId!] == nil {
            return false
        }
        
        return true
    }
    
    func detemineUserLevel() {
        if (self.setupKey != nil) {
            userLevel = .setup
            return
        }
        
        let adminKey = self.getAdminKey()
        let memberKey = self.getMemberKey()
        let guestKey = self.getGuestKey()
        
        if (adminKey != nil && adminKey!.count == 16) {
            userLevel = .admin
        }
        else if (memberKey != nil && memberKey!.count == 16) {
            userLevel = .member
        }
        else if (guestKey != nil && guestKey!.count == 16) {
            userLevel = .guest
        }
        else {
            userLevel = .unknown
        }
    }
    
    public func invalidateSessionNonce() {
        self.sessionNonce = nil
    }
    
    public func setSessionNonce(_ sessionNonce: [UInt8]) {
        self.sessionNonce = sessionNonce
    }
    
    public func loadSetupKey(_ setupKey: [UInt8]) {
        self.setupKey = setupKey
        self.detemineUserLevel()
    }
    
    public func exitSetup() {
        self.setupKey = nil
        self.detemineUserLevel()
    }
    
    public func disableEncryptionTemporarily() {
        self.temporaryDisable = true
        self.detemineUserLevel()
    }
    
    public func restoreEncryption() {
        self.temporaryDisable = false
        self.detemineUserLevel()
    }
    
    public func isTemporarilyDisabled() -> Bool {
        return temporaryDisable
    }
    
    public func isEncryptionEnabled() -> Bool {
        if (temporaryDisable == true) {
            return false
        }
        return encryptionEnabled
    }
}
