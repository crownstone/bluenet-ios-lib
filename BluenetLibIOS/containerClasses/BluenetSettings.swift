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
    public var adminKey : [UInt8]?
    public var memberKey  : [UInt8]?
    public var guestKey : [UInt8]?
    public var initializedKeys = false
    
    init() {}
    
    public init(encryptionEnabled: Bool, adminKey: String, memberKey: String, guestKey: String) {
        self.encryptionEnabled = encryptionEnabled
        self.adminKey = Conversion.string_to_uint8_array(adminKey)
        self.memberKey = Conversion.string_to_uint8_array(memberKey)
        self.guestKey = Conversion.string_to_uint8_array(guestKey)
        self.initializedKeys = true
    }
    
    
}