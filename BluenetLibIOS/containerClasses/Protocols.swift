//
//  Protocols.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 20/01/2017.
//  Copyright © 2017 Alex de Mulder. All rights reserved.
//

import Foundation

public protocol iBeaconPacketProtocol {
    var uuid : String { get }
    var major: NSNumber { get }
    var minor: NSNumber { get }
    var rssi : NSNumber { get }
    var distance : NSNumber { get }
    var idString: String { get }
    var collectionId: String { get }
}

public protocol LocalizationClassifier {
    func classify(_ inputVector: [iBeaconPacketProtocol], collectionId: String) -> String?
}
