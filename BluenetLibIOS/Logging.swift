//
//  Logging.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 06/12/2016.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

func Log(_ data: String) {
    if (LOGGING_PRINT) {
        print(data)
    }

    if (LOGGING_FILE) {
        let dir: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last! as URL
        let url = dir.appendingPathComponent("BluenetLog.log")
    
        let timestring = Date().timeIntervalSince1970
        let content = "\(timestring) - " + data + "\n"
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
