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
    open var adminKey : [UInt8]?
    open var memberKey  : [UInt8]?
    open var guestKey : [UInt8]?
    open var setupKey  : [UInt8]?
    open var initializedKeys = false
    open var sessionNonce : [UInt8]?
    open var referenceId : String = "unknown"
    
    open var userLevel : UserLevel = .unknown
    
    init() {}
    
    public func loadKeys(encryptionEnabled: Bool, adminKey: String?, memberKey: String?, guestKey: String?, referenceId: String) {
        self.encryptionEnabled = encryptionEnabled
        self.referenceId = referenceId
        
        if (adminKey != nil) {
            self.adminKey = Conversion.ascii_or_hex_string_to_16_byte_array(adminKey!)
        }
        else {
            self.adminKey = [0];
        }
        if (memberKey != nil) {
            self.memberKey = Conversion.ascii_or_hex_string_to_16_byte_array(memberKey!)
        }
        else {
            self.memberKey = [0];
        }
        if (guestKey != nil) {
            self.guestKey = Conversion.ascii_or_hex_string_to_16_byte_array(guestKey!)
        }
        else {
            self.guestKey = [0];
        }
        
        self.initializedKeys = true
        
        detemineUserLevel()
    }
    
    func detemineUserLevel() {
        if (self.adminKey!.count == 16) {
            userLevel = .admin
        }
        else if (self.memberKey!.count == 16) {
            userLevel = .member
        }
        else if (self.guestKey!.count == 16) {
            userLevel = .guest
        }
        else {
            userLevel = .unknown
            self.initializedKeys = false
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
        userLevel = .setup
    }
    
    open func exitSetup() {
        self.setupKey = nil
        detemineUserLevel()
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
