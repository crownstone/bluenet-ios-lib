//
//  BluenetSettings.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 21/07/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation


public class BluenetSettings {
    public var encryptionsEnabled = false
    public var temporaryDisable = false
    public var adminKey : [UInt8]?
    public var memberKey  : [UInt8]?
    public var guestKey : [UInt8]?
    public var setupKey  : [UInt8]?
    public var initializedKeys = false
    public var sessionNonce : [UInt8]?
    
    public var userLevel : UserLevel = .UNKNOWN
    
    init() {}
    
    public init(encryptionEnabled: Bool, adminKey: String, memberKey: String, guestKey: String) {
        self.encryptionsEnabled = encryptionEnabled
        self.adminKey = Conversion.string_to_uint8_array(adminKey)
        self.memberKey = Conversion.string_to_uint8_array(memberKey)
        self.guestKey = Conversion.string_to_uint8_array(guestKey)
        self.initializedKeys = true
        
        detemineUserLevel()
    }
    
    func detemineUserLevel() {
        if (self.adminKey!.count == 16) {
            userLevel = .Admin
        }
        else if (self.memberKey!.count == 16) {
            userLevel = .Member
        }
        else if (self.guestKey!.count == 16) {
            userLevel = .Guest
        }
        else {
            userLevel = .UNKNOWN
            self.initializedKeys = false
        }
    }
    
    public func invalidateSessionNonce() {
        self.sessionNonce = nil
    }
    
    public func setSessionNonce(sessionNonce: [UInt8]) {
        self.sessionNonce = sessionNonce
    }
    
    public func loadSetupKey(setupKey: [UInt8]) {
        self.setupKey = setupKey
        userLevel = .Setup
    }
    
    public func exitSetup() {
        self.setupKey = nil
        detemineUserLevel()
    }
    
    public func disableEncryptionTemporarily() {
        self.temporaryDisable = true
    }
    
    public func restoreEncryption() {
        self.temporaryDisable = false
    }
    
    public func isEncryptionEnabled() -> Bool {
        if (temporaryDisable == true) {
            return false
        }
        return encryptionsEnabled
    }
}