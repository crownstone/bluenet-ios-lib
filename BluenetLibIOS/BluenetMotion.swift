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

    var activityManager: CMMotionActivityManager!
    var motionManager: CMMotionManager!
    
    public init() {
        activityManager = CMMotionActivityManager()
        motionManager = CMMotionManager()
        
        motionManager.deviceMotionUpdateInterval = 0.4
    
        print("is activity available: \(CMMotionActivityManager.isActivityAvailable())")
        
        if (CMMotionActivityManager.isActivityAvailable()) {
            activityManager.startActivityUpdates(to: OperationQueue.main, withHandler: {motion in
                Log("activity \(motion)", filename: "activity.log")
            })
        }
        
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main, withHandler: {motion, error in
            Log("motion \(motion)", filename: "motion.log")
        })
        
       

    }
}

    
