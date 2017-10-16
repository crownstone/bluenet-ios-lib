//
//  BluenetCBDelegateBackground.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 16/10/2017.
//  Copyright © 2017 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreBluetooth
import SwiftyJSON
import PromiseKit

open class BluenetCBDelegateBackground: BluenetCBDelegate {
    
    override init(bleManager: BleManager) {
        super.init(bleManager: bleManager);
    }
    
    open func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        LOG.info("BLUENET_LIB: WILL RESTORE STATE \(dict)");
    }
}

