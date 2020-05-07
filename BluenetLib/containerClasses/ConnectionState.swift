//
//  ConnectionState.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 29/10/2019.
//  Copyright © 2019 Alex de Mulder. All rights reserved.
//

import Foundation

public enum ConnectionProtocolVersion: UInt8 {
    case legacy = 0
    case v1 = 1
    case v2 = 2
    case v3 = 3
    case v5 = 5 // PROTOCOL V5, versioning based on protocol version starts here.
    
    case unknown = 255
}




class ConnectionState {
    
    var connectionProtocolVersion : ConnectionProtocolVersion = .unknown
    var operationMode : CrownstoneMode = .unknown
    var keySet : KeySet?
    var protocolVersion : UInt8 = 0
    var sessionNonce : [UInt8]?
    var validationKey : [UInt8]?
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
        self.setupKey = nil
        self.keySet = nil
        self.operationMode = .unknown
        self.connectionProtocolVersion = .unknown
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
    
    func validationKey(_ validationKey: [UInt8]) {
        self.validationKey = validationKey
    }
    
    func setProtocolVersion(_ protocolVersion: UInt8) {
        self.protocolVersion = protocolVersion
    }
    
    func setConnectionProtocolVersion(_ version: ConnectionProtocolVersion) {
        ControlPacketsGenerator.connectionProtocolVersion = version
        StatePacketsGenerator.connectionProtocolVersion = version
        self.connectionProtocolVersion = version
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
