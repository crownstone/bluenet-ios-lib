//
//  KeySet.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 30/08/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation


open class KeySet {
    open var adminKey  : [UInt8]? = nil
    open var memberKey : [UInt8]? = nil
    open var guestKey  : [UInt8]? = nil
    open var initializedKeys = false
    open var referenceId : String = "unknown"
    open var userLevel : UserLevel = .unknown
    
    init(adminKey: String?, memberKey: String?, guestKey: String?, referenceId: String) {
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
    
    
}
