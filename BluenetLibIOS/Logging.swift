//
//  Logging.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 06/12/2016.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import UIKit

func Log(_ data: String) {
    Log(data, filename: "BluenetLog.log")
}

func Log(_ data: String, filename: String = "BluenetLog.log") {
    if (LOGGING_PRINT) {
        print(data)
    }
    LogFile(data, filename: filename)
}

func LogFile(_ data: String, filename: String = "BluenetLog.log") {
    if (LOGGING_FILE) {
        let dir: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last! as URL
        let url = dir.appendingPathComponent(filename)
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        let battery = UIDevice.current.batteryLevel
        
        let timestamp = Date().timeIntervalSince1970
        let time = Date().description
        let content = "\(timestamp) - \(time):battery:\(battery) - " + data + "\n"
        let contentToWrite = content.data(using: String.Encoding.utf8)!
        
        if let fileHandle = FileHandle(forWritingAtPath: url.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(contentToWrite)
        }
        else {
            do {
                try contentToWrite.write(to: url, options: .atomic)
            }
            catch {
                print("Could not write to file \(error)")
            }
        }
    }

}
