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
    
    init () {
        
    }
    
    func setControlVersion(_ version: ControlVersionType) {
        ControlPacketsGenerator.controlVersion = version
        StatePacketsGenerator.controlVersion = version
        self.controlVersion = version
    }
    
    func setOperationMode(_ mode: CrownstoneMode) {
        self.operationMode = mode
    }
    
    
}
