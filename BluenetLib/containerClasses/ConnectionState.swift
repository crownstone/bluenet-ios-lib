//
//  ConnectionState.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 29/10/2019.
//  Copyright © 2019 Alex de Mulder. All rights reserved.
//

import Foundation

public enum ControlVersionType: UInt8 {
    case unknown = 0
    case v1 = 1
    case v2 = 2
}




class ConnectionState {
    
    var controlVersion : ControlVersionType = .unknown
    var operationMode : CrownstoneMode = .unknown
    var keySet : KeySet?
    var sessionNonce : [UInt8]?
    var encryptionEnabled: Bool = true
    var temporaryEncryptionDisabled : Bool = false
    
    var setupKey : [UInt8]?
    
    var userLevel : UserLevel = .unknown
    
    init () {}
    
    func checkEncryptionState(settings: BluenetSettings) {
        self.encryptionEnabled = settings.encryptionEnabled
    }
    
    func clear() {
        self.sessionNonce = nil
        self.keySet = nil
        self.operationMode = .unknown
        self.controlVersion = .unknown
    }

    func start(settings: BluenetSettings) {
        self.clear()
        self.checkEncryptionState(settings: settings)
    }
    
    func isEncryptionEnabled() -> Bool {
        return self.encryptionEnabled && !self.temporaryEncryptionDisabled
    }
    
    func setActiveKeySet(_ keySet: KeySet) {
        self.keySet = keySet
        self.detemineUserLevel()
    }
    
    func setSessionNonce(_ sessionNonce: [UInt8]) {
        self.sessionNonce = sessionNonce
    }
    
    func setControlVersion(_ version: ControlVersionType) {
        ControlPacketsGenerator.controlVersion = version
        StatePacketsGenerator.controlVersion = version
        self.controlVersion = version
    }
    
    func setOperationMode(_ mode: CrownstoneMode) {
        self.operationMode = mode
    }
    
    func restoreEncryption() {
         self.temporaryEncryptionDisabled = false
    }
    
    func disableEncryptionTemporarily() {
        self.temporaryEncryptionDisabled = true
    }
    
    func loadSetupKey(_ key: [UInt8]) {
        self.setupKey = key
        self.detemineUserLevel()
    }
    
    func exitSetup() {
        self.setupKey = nil
        self.detemineUserLevel()
    }

    func isTemporarilyDisabled() -> Bool {
        return self.temporaryEncryptionDisabled
    }
    
    func detemineUserLevel() {
        if (self.setupKey != nil) {
            userLevel = .setup
            return
        }

        let adminKey  = self.keySet?.adminKey
        let memberKey = self.keySet?.memberKey
        let basicKey  = self.keySet?.basicKey

        if (adminKey != nil && adminKey!.count == 16) {
            userLevel = .admin
        }
        else if (memberKey != nil && memberKey!.count == 16) {
            userLevel = .member
        }
        else if (basicKey != nil && basicKey!.count == 16) {
            userLevel = .basic
        }
        else {
            userLevel = .unknown
        }
    }
    
    
    func getBasicKey() -> [UInt8]? {
        return self.keySet?.basicKey
    }
    
    
}
