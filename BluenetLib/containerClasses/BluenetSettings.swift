//
//  BluenetSettings.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 21/07/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation


open class BluenetSettings {
    open var encryptionEnabled = false
    open var temporaryDisable = false
    
    open var sessionReferenceId : String? = nil

    open var keySets = [String: KeySet]()
    open var keySetList = [KeySet]()
    
    open var setupKey     : [UInt8]? = nil
    open var sessionNonce : [UInt8]? = nil
    
    open var userLevel : UserLevel = .unknown
    
    
    init() {}
    
    public func loadKeySets(encryptionEnabled: Bool, keySets: [KeySet]) {
        self.encryptionEnabled = encryptionEnabled
        self.keySetList = keySets
        for keySet in keySets {
            self.keySets[keySet.referenceId] = keySet
        }
    }
    
    public func getGuestKey(referenceId: String) -> [UInt8]? {
        if self.keySets[referenceId] != nil {
            return self.keySets[referenceId]!.guestKey
        }
        else {
            return nil
        }
    }
    
    open func setSessionId(referenceId: String) -> Bool {
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
    
    open func invalidateSessionNonce() {
        self.sessionNonce = nil
    }
    
    open func setSessionNonce(_ sessionNonce: [UInt8]) {
        self.sessionNonce = sessionNonce
    }
    
    open func loadSetupKey(_ setupKey: [UInt8]) {
        self.setupKey = setupKey
    }
    
    open func exitSetup() {
        self.setupKey = nil
    }
    
    open func disableEncryptionTemporarily() {
        self.temporaryDisable = true
    }
    
    open func restoreEncryption() {
        self.temporaryDisable = false
    }
    
    open func isTemporarilyDisabled() -> Bool {
        return temporaryDisable
    }
    
    open func isEncryptionEnabled() -> Bool {
        if (temporaryDisable == true) {
            return false
        }
        return encryptionEnabled
    }
}
