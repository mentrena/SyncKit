//
//  TempFileManager.swift
//  Pods-CoreDataExample
//
//  Created by Manuel Entrena on 25/04/2019.
//

import Foundation

class TempFileManager {
    
    let identifier: String
    init(identifier: String) {
        self.identifier = identifier
    }
    
    private lazy var assetDirectory: URL = {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.mentrena.QSTempFileManager").appendingPathComponent(identifier)
        
        if FileManager.default.fileExists(atPath: directoryURL.path) == false {
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        return directoryURL
    }()
    
    func store(data: Data) -> URL {
        
        let fileName = ProcessInfo.processInfo.globallyUniqueString
        let url = assetDirectory.appendingPathComponent(fileName)
        try? data.write(to: url, options: .atomicWrite)
        return url
    }
    
    func clearTempFiles() {
        
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: assetDirectory, includingPropertiesForKeys: nil, options: []) else {
            return
        }
        
        for fileURL in fileURLs {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
