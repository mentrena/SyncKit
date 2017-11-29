//
//  QSCloudKitSynchronizer+RealmSwift.swift
//  Pods
//
//  Created by Manuel Entrena on 01/09/2017.
//
//

import Foundation
import RealmSwift
import CloudKit

extension QSCloudKitSynchronizer {
    
    public class func realmPath(appGroup: String? = nil) -> String {
        
        let url = URL(fileURLWithPath: applicationBackupRealmPath(suiteName: appGroup))
        return url.appendingPathComponent(realmFileName()).path
    }
    
    class func applicationBackupRealmPath(suiteName: String? = nil) -> String {
        
        let rootDirectory: String
        if let suiteName = suiteName {
            rootDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)!.path
        } else {
            rootDirectory = applicationDocumentsDirectory()
        }
        let url = URL(fileURLWithPath: rootDirectory)
        return url.appendingPathComponent("Realm").path
    }
    
    class func applicationDocumentsDirectory() -> String {
        #if TARGET_OS_IPHONE
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last!
        #else
            let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            return urls.last!.appendingPathComponent("com.mentrena.QSCloudKitSynchronizer").path
        #endif
    }
    
    class func realmFileName() -> String {
        
        return "QSSyncStore.realm"
    }
    
    public class func persistenceConfiguration(suiteName: String? = nil) -> Realm.Configuration {
    
        var configuration = RealmSwiftChangeManager.defaultPersistenceConfiguration()
        configuration.fileURL = URL(fileURLWithPath: realmPath(appGroup: suiteName))
        return configuration
    }
    
    class func ensurePathAvailable(suiteName: String?) {
        
        if !FileManager.default.fileExists(atPath: applicationBackupRealmPath(suiteName: suiteName)) {
            try! FileManager.default.createDirectory(atPath: applicationBackupRealmPath(suiteName: suiteName), withIntermediateDirectories: true)
        }
    }
    
    public class func defaultCustomZoneID() -> CKRecordZoneID {
        
        return CKRecordZoneID(zoneName: "QSCloudKitCustomZoneName", ownerName: CKCurrentUserDefaultName)
    }
    
    public class func cloudKitSynchronizer(containerName: String, configuration: Realm.Configuration, suiteName: String? = nil) -> QSCloudKitSynchronizer {
        
        ensurePathAvailable(suiteName: suiteName)
        let changeManager = RealmSwiftChangeManager(persistenceRealmConfiguration: persistenceConfiguration(suiteName: suiteName), targetRealmConfiguration: configuration, recordZoneID: defaultCustomZoneID())
        return QSCloudKitSynchronizer(containerIdentifier: containerName, recordZoneID: defaultCustomZoneID(), changeManager: changeManager, suiteName: suiteName)
    }
    
}
