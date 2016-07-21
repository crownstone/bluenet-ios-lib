//
//  BluenetSettings.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 21/07/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation


public class BluenetSettings {
    var encryptionEnabled = true
    var adminKey : [UInt8]?
    var userKey  : [UInt8]?
    var guestKey : [UInt8]?
    var initializedKeys = false
    
    init() {

    }
    
    
}