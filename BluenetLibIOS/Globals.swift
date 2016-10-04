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

public func setBluenetGlobals(viewController: UIViewController, appName: String) {
    VIEWCONTROLLER = viewController;
    APPNAME = appName
}
