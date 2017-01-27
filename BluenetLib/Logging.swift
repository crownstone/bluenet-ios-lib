//
//  Logging.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 06/12/2016.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import UIKit


public enum LogLevel : Int {
    case VERBOSE = 0
    case DEBUG
    case INFO
    case WARN
    case ERROR
    case NONE
}


open class LogClass {
    let dir: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last! as URL
    
    var logPrintLevel : LogLevel = .INFO
    var logFileLevel  : LogLevel = .NONE
    var logBaseFilename : String = "BluenetLib"
    
    var daysToStoreLogs : Int = 3
    
    
    
    init() {
        cleanLogs()
    }
    
    init(logBaseFilename: String) {
        self.logBaseFilename = logBaseFilename
        cleanLogs()
    }
    
    open func setPrintLevel(_ level : LogLevel) {
        logPrintLevel = level
    }
    open func setFileLevel(_ level : LogLevel) {
        logFileLevel = level
    }
    
    /**
     * Will remove all logs that have a different name before changing the name.
     */
    open func setBaseFilename(baseFilename: String) {
        clearLogs()
        logBaseFilename = baseFilename
        cleanLogs()
    }
    
    open func verbose(_ data: String) {
        _log(data, level: .VERBOSE, explicitNoWriteToFile: false)
    }
    
    open func debug(_ data: String) {
        _log(data, level: .DEBUG, explicitNoWriteToFile: false)
    }
    
    open func info(_ data: String) {
        _log(data, level: .INFO, explicitNoWriteToFile: false)
    }
    
    open func warn(_ data: String) {
        _log(data, level: .WARN, explicitNoWriteToFile: false)
    }
    
    open func error(_ data: String) {
        _log(data, level: .ERROR, explicitNoWriteToFile: false)
    }
    
    open func fileError(_ data: String) {
        _log(data, level: .ERROR, explicitNoWriteToFile: true)
    }
    
    open func file(_ data: String, filenameBase: String) {
        _logFile(data, filenameBase: logBaseFilename)
    }
    
    open func file(_ data: String) {
        _logFile(data, filenameBase: logBaseFilename)
    }
    
    
    open func clearLogs() {
        clearLogs(storeAmountOfDays: 0)
    }
    
    open func cleanLogs() {
        clearLogs(storeAmountOfDays: daysToStoreLogs)
    }
    
    open func clearLogs(storeAmountOfDays: Int) {
        var allowedNames = Set<String>()
        if (storeAmountOfDays > 0) {
            for i in [Int](0...storeAmountOfDays-1) {
                let date = Date().addingTimeInterval((-24 * 3600 * Double(i)))
                allowedNames.insert(_getFilename(filenameBase: self.logBaseFilename, date: date))
            }
        }
        
        let filemanager = FileManager()
        let files = try? filemanager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
        if let filesFound = files {
            for file in filesFound {
                let filename = file.lastPathComponent
                if (filename.contains(self.logBaseFilename)) {
                    if (allowedNames.contains(filename) == false) {
                        do {
                            try filemanager.removeItem(atPath: file.absoluteString)
                        }
                        catch {
                            self.fileError("Could not remove file \(filename) at \(file.absoluteString)")
                        }
                    }
                }
            }
        }
        
    }

    
    
    func _log(_ data: String, level: LogLevel, explicitNoWriteToFile: Bool = false) {
        if (logPrintLevel.rawValue <= level.rawValue) {
            print(data)
        }
        if (logFileLevel.rawValue <= level.rawValue && explicitNoWriteToFile == false) {
            _logFile(data, filenameBase: logBaseFilename)
        }
    }
    
    
    func _logFile(_ data: String, filenameBase: String) {
        
        let date = Date()
        let filename = _getFilename(filenameBase: filenameBase, date: date);
        
        let url = dir.appendingPathComponent(filename)
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        let battery = UIDevice.current.batteryLevel
        
        let timestamp = Date().timeIntervalSince1970
        let time = Date().description
        let content = "\(timestamp) @ \(time) - battery:\(battery) - " + data + "\n"
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
                self.fileError("Could not write to file \(error)")
            }
        }
    }
    
    func _getFilename(filenameBase: String, date: Date) -> String {
        let styler = DateFormatter()
        styler.dateFormat = "yyyy-MM-dd"
        let dateString = styler.string(from: date)
        let filename = filenameBase + dateString + ".log"
        
        return filename
    }
    
}
