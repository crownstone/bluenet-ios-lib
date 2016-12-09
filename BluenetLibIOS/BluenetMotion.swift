//
//  BluenetMotion.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 08/12/2016.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import CoreMotion


open class BluenetMotion  {

    var motionManager: CMMotionManager!
    
    public init() {
        motionManager = CMMotionManager()
        
        motionManager.deviceMotionUpdateInterval = 0.4
    
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main, withHandler: {motion, error in
            LogFile("motion \(motion)", filename: "motion.log")
        })
        
       

    }
}

    
