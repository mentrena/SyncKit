//
//  DefaultRealmProvider.swift
//  Pods
//
//  Created by Manuel Entrena on 25/05/2018.
//

import Foundation
import RealmSwift

// For Swift
public extension Notification.Name {
    public static let realmProviderDidAddAdapter = NSNotification.Name("realmProviderDidAddAdapter")
    public static let realmProviderDidRemoveAdapter = NSNotification.Name("realmProviderDidRemoveAdapter")
}

// For Obj-C
public extension NSNotification {
    public static let DefaultRealmProviderDidAddAdapterNotification: NSString = "realmProviderDidAddAdapter"
    public static let DefaultRealmProviderDidRemoveAdapterNotification: NSString = "realmProviderDidRemoveAdapter"
}

public class DefaultRealmProvider: NSObject, QSCloudKitSynchronizerAdapterProvider {
    
    let identifier: String
    private(set) var adapterDictionary: [CKRecordZoneID: RealmSwiftAdapter]
    private(set) var realms: [CKRecordZoneID: Realm.Configuration]
    let appGroup: String?
    let realmConfiguration: Realm.Configuration
    
    private let DefaultRealmProviderTargetFileName = "DefaultRealmProviderTargetFileName"
    private let DefaultRealmProviderPersistenceFileName = "DefaultRealmProviderPersistenceFileName"
    
    public init(identifier: String, realmConfiguration: Realm.Configuration, appGroup: String?) {
        self.identifier = identifier
        self.appGroup = appGroup
        adapterDictionary = [CKRecordZoneID: RealmSwiftAdapter]()
        realms = [CKRecordZoneID: Realm.Configuration]()
        self.realmConfiguration = realmConfiguration
        super.init()
        bringUpDataStacks()
    }
    
    private class func applicationDocumentsDirectory() -> String {
        
        #if os(iOS)
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last!
        #else
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls.last!.appendingPathComponent("com.mentrena.QSCloudKitSynchronizer").path
        #endif
    }
    
    private class func applicationDocumentsDirectoryForAppGroup(_ suiteName: String?) -> String {
        
        if let suiteName = suiteName {
            return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)!.path
        } else {
            return applicationDocumentsDirectory()
        }
    }
    
    private func stackProviderStoresPath(appGroup: String?) -> String {
        let documentsDirectory = DefaultRealmProvider.applicationDocumentsDirectoryForAppGroup(appGroup) as NSString
        let storesPath = documentsDirectory.appendingPathComponent("Stores") as NSString
        return storesPath.appendingPathComponent(identifier)
    }
    
    private var directoryURL: URL {
        return URL(fileURLWithPath: stackProviderStoresPath(appGroup: appGroup))
    }
    
    private func bringUpDataStacks() {
        
        let folderURL = URL(fileURLWithPath: stackProviderStoresPath(appGroup: appGroup))
        if let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: [URLResourceKey.nameKey, URLResourceKey.isDirectoryKey], options: [.skipsSubdirectoryDescendants]) {
            
            for case let url as URL in enumerator {
                let folderName = url.lastPathComponent
                let zoneIDComponents = folderName.components(separatedBy: ".zoneID.")
                let zoneID = CKRecordZoneID(zoneName: zoneIDComponents[0], ownerName: zoneIDComponents[1])
                let stackURL = url.appendingPathComponent(DefaultRealmProviderTargetFileName)
                let persistenceURL = url.appendingPathComponent(DefaultRealmProviderPersistenceFileName)
                let adapter = realmSwiftAdapterFor(targetRealmURL:stackURL, persistenceRealmURL: persistenceURL, zoneID: zoneID)
                adapterDictionary[zoneID] = adapter
            }
        }
        
    }
    
    private func realmSwiftAdapterFor(targetRealmURL: URL, persistenceRealmURL: URL, zoneID: CKRecordZoneID) -> RealmSwiftAdapter {
        
        let targetConfiguration = Realm.Configuration(fileURL: targetRealmURL,
                                                      inMemoryIdentifier: self.realmConfiguration.inMemoryIdentifier,
                                                      syncConfiguration: self.realmConfiguration.syncConfiguration,
                                                      encryptionKey: self.realmConfiguration.encryptionKey,
                                                      readOnly: self.realmConfiguration.readOnly,
                                                      schemaVersion: self.realmConfiguration.schemaVersion,
                                                      migrationBlock: self.realmConfiguration.migrationBlock,
                                                      deleteRealmIfMigrationNeeded: self.realmConfiguration.deleteRealmIfMigrationNeeded,
                                                      shouldCompactOnLaunch: self.realmConfiguration.shouldCompactOnLaunch,
                                                      objectTypes: self.realmConfiguration.objectTypes)
        
        var persistenceConfiguration = RealmSwiftAdapter.defaultPersistenceConfiguration()
        persistenceConfiguration.fileURL = persistenceRealmURL
        
        realms[zoneID] = targetConfiguration
        
        return RealmSwiftAdapter(persistenceRealmConfiguration: persistenceConfiguration,
                                       targetRealmConfiguration: targetConfiguration,
                                       recordZoneID: zoneID)
    }
    
    private func folderNameFor(recordZoneID: CKRecordZoneID) -> String {
        return recordZoneID.zoneName + ".zoneID." + recordZoneID.ownerName
    }
    
    public func cloudKitSynchronizer(_ synchronizer: QSCloudKitSynchronizer, modelAdapterFor recordZoneID: CKRecordZoneID) -> QSModelAdapter? {
        
        if let adapter = adapterDictionary[recordZoneID] {
            return adapter
        }
        
        let folderName = folderNameFor(recordZoneID: recordZoneID)
        let folderURL = directoryURL.appendingPathComponent(folderName)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let stackURL = folderURL.appendingPathComponent(DefaultRealmProviderTargetFileName)
        let persistenceURL = folderURL.appendingPathComponent(DefaultRealmProviderPersistenceFileName)
        
        let adapter = realmSwiftAdapterFor(targetRealmURL: stackURL, persistenceRealmURL: persistenceURL, zoneID: recordZoneID)
        
        adapterDictionary[recordZoneID] = adapter
        
        NotificationCenter.default.post(name: .realmProviderDidAddAdapter, object: self, userInfo:["CKRecordZoneID": recordZoneID])
        
        return adapter
    }
    
    public func cloudKitSynchronizer(_ synchronizer: QSCloudKitSynchronizer, zoneWasDeletedWith recordZoneID: CKRecordZoneID) {
        
        guard let adapter = adapterDictionary[recordZoneID],
            adapter.serverChangeToken() != nil else {
                return
        }
        
        adapter.deleteChangeTracking()
        
        adapterDictionary[recordZoneID] = nil
        realms[recordZoneID] = nil

        synchronizer.removeModelAdapter(adapter)
        
        let folderName = folderNameFor(recordZoneID: recordZoneID)
        let folderURL = directoryURL.appendingPathComponent(folderName)
        try? FileManager.default.removeItem(at: folderURL)
        
        NotificationCenter.default.post(name: .realmProviderDidRemoveAdapter, object: self, userInfo:["CKRecordZoneID": recordZoneID])
    }
}
