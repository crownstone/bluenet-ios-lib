//
//  BluenetSettings.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 21/07/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation


public class BluenetSettings {
    public var encryptionEnabled = false
    public var temporaryDisable = false
    public var adminKey  : [UInt8]? = nil
    public var memberKey : [UInt8]? = nil
    public var guestKey  : [UInt8]? = nil
    public var setupKey  : [UInt8]? = nil
    public var initializedKeys = false
    public var sessionNonce : [UInt8]? = nil
    public var referenceId : String = "unknown"
    
    public var userLevel : UserLevel = .unknown
    
    init() {}
    
    public func loadKeys(encryptionEnabled: Bool, adminKey: String?, memberKey: String?, guestKey: String?, referenceId: String) {
        self.encryptionEnabled = encryptionEnabled
        self.referenceId = referenceId
       
        if (adminKey != nil) {
            self.adminKey = Conversion.ascii_or_hex_string_to_16_byte_array(adminKey!)
        }
        else {
            self.adminKey = nil;
        }
        if (memberKey != nil) {
            self.memberKey = Conversion.ascii_or_hex_string_to_16_byte_array(memberKey!)
        }
        else {
            self.memberKey = nil;
        }
        if (guestKey != nil) {
            self.guestKey = Conversion.ascii_or_hex_string_to_16_byte_array(guestKey!)
        }
        else {
            self.guestKey = nil;
        }
        
        self.initializedKeys = true
        
        detemineUserLevel()
    }
    
    func detemineUserLevel() {
        if (self.adminKey != nil && self.adminKey!.count == 16) {
            userLevel = .admin
        }
        else if (self.memberKey != nil && self.memberKey!.count == 16) {
            userLevel = .member
        }
        else if (self.guestKey != nil && self.guestKey!.count == 16) {
            userLevel = .guest
        }
        else {
            userLevel = .unknown
            self.initializedKeys = false
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
        userLevel = .setup
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
