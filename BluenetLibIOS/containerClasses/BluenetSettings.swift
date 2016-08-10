//
//  BluenetSettings.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 21/07/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation


public class BluenetSettings {
    public var encryptionEnabled = true
    public var adminKey : [UInt8]?
    public var userKey  : [UInt8]?
    public var guestKey : [UInt8]?
    public var initializedKeys = false
    
    init() {

    }
    
    
}