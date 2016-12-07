//
//  Globals.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 17/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import UIKit

// these globals are used to trigger pop up alerts and to show the app name inside of them

var APPNAME = "Crownstone"
var VIEWCONTROLLER : UIViewController?
var LOGGING_PRINT = true
var LOGGING_FILE = false
var DEBUG_LOG_ENABLED = false

public func setBluenetGlobals(viewController: UIViewController, appName: String, loggingPrint: Bool = true, loggingFile: Bool = false, debugLogEnabled: Bool = false) {
    VIEWCONTROLLER = viewController
    APPNAME        = appName
    LOGGING_PRINT  = loggingPrint
    LOGGING_FILE   = loggingFile
    DEBUG_LOG_ENABLED = debugLogEnabled
}
