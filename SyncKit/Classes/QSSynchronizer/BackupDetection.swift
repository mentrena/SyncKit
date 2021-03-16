//
//  QSBackupDetection.swift
//  Pods
//
//  Created by Manuel Entrena on 04/04/2019.
//

import Foundation

class BackupDetection: NSObject {
    
    @objc enum DetectionResult: Int {
        case firstRun
        case restoredFromBackup
        case regularLaunch
    }
    
    fileprivate static let backupDetectionStoreKey = "QSBackupDetectionStoreKey"
    fileprivate static var applicationDocumentsDirectory: String {
    #if os(iOS) || os(watchOS)
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
    #else
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls.last?.appendingPathComponent("com.mentrena.QSCloudKitSynchronizer").path ?? ""
    #endif
    }
    
    fileprivate static let fileName = "backupDetection"
    fileprivate static var backupDetectionFilePath: String {
        return NSString.path(withComponents: [applicationDocumentsDirectory, fileName])
    }
   
    @objc
    static func runBackupDetection(completion: (DetectionResult, Error?) -> ()) {
        
        let result: DetectionResult
        if FileManager.default.fileExists(atPath: backupDetectionFilePath) {
            result = .regularLaunch
        } else if UserDefaults.standard.bool(forKey: backupDetectionStoreKey) {
            result = .restoredFromBackup
        } else {
            result = .firstRun
        }
        
        var error: Error?
        if result == .firstRun || result == .restoredFromBackup {
            let content = "Backup detection file\n"
            let fileContents = content.data(using: .utf8)
            FileManager.default.createFile(atPath: backupDetectionFilePath, contents: fileContents, attributes: nil)
            var fileURL = URL(fileURLWithPath: backupDetectionFilePath)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            do {
                try fileURL.setResourceValues(resourceValues)
            } catch let err {
                error = err
            }
        }
        
        completion(result, error)
    }
}
