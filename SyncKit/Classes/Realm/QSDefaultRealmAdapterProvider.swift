//
//  QSDefaultRealmAdapterProvider.swift
//  Pods
//
//  Created by Manuel Entrena on 18/11/2018.
//

import Foundation
import CloudKit
import Realm

@objc public class QSDefaultRealmAdapterProvider: NSObject, QSCloudKitSynchronizerAdapterProvider {
    
    let zoneID: CKRecordZone.ID
    let persistenceConfiguration: RLMRealmConfiguration
    let targetConfiguration: RLMRealmConfiguration
    let appGroup: String?
    @objc public private(set) var adapter: QSRealmAdapter!
    
    @objc public init(targetConfiguration: RLMRealmConfiguration, zoneID: CKRecordZone.ID, appGroup: String? = nil) {
        self.targetConfiguration = targetConfiguration
        self.zoneID = zoneID
        self.appGroup = appGroup
        persistenceConfiguration = QSDefaultRealmAdapterProvider.createPersistenceConfiguration(suiteName: appGroup)
        super.init()
        adapter = createAdapter()
    }
    
    @objc public func cloudKitSynchronizer(_ synchronizer: QSCloudKitSynchronizer, modelAdapterFor recordZoneID: CKRecordZone.ID) -> QSModelAdapter? {
        
        guard recordZoneID == zoneID else { return nil }
        
        return adapter
    }
    
    @objc public func cloudKitSynchronizer(_ synchronizer: QSCloudKitSynchronizer, zoneWasDeletedWith recordZoneID: CKRecordZone.ID) {
        
        let adapterHasSyncedBefore = adapter.serverChangeToken() != nil
        if recordZoneID == zoneID && adapterHasSyncedBefore {
            
            adapter.deleteChangeTracking()
            synchronizer.removeModelAdapter(adapter)
            
            adapter = createAdapter()
            synchronizer.addModelAdapter(adapter)
        }
    }
    
    fileprivate func createAdapter() -> QSRealmAdapter {
        
        return QSRealmAdapter(persistenceRealmConfiguration: persistenceConfiguration, targetRealmConfiguration: targetConfiguration, recordZoneID: zoneID)
    }
    
    // MARK: - File directory
    
    /**
     *  If using app groups, SyncKit offers the option to store its tracking database in the shared container so that it's
     *  accessible by SyncKit from any of the apps in the group. This method returns the path used in this case.
     *
     *  @param  appGroup   Identifier of an App Group this app belongs to.
     *
     *  @return File path, in the shared container, where SyncKit will store its tracking database.
     */
    
    @objc public static func realmPath(appGroup: String?) -> String {
        return applicationBackupRealmPath(suiteName: appGroup).appending(realmFileName())
    }
    
    fileprivate static func applicationBackupRealmPath(suiteName: String?) -> String! {
        let rootDirectory: String?
        if let suiteName = suiteName {
            rootDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)?.path
        } else {
            rootDirectory = applicationDocumentsDirectory()
        }
        return rootDirectory?.appending("Realm")
    }
    
    fileprivate static func applicationDocumentsDirectory() -> String? {
        #if TARGET_OS_IPHONE
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last
        #else
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls.last?.appendingPathComponent("com.mentrena.QSCloudKitSynchronizer").path
        #endif
    }
    
    fileprivate static func realmFileName() -> String {
        return "QSSyncStore.realm"
    }
    
    fileprivate static func createPersistenceConfiguration(suiteName: String?) -> RLMRealmConfiguration {
        ensurePathAvailable(suiteName: suiteName)
        let configuration = QSRealmAdapter.defaultPersistenceConfiguration()
        configuration.fileURL = URL(fileURLWithPath: realmPath(appGroup: suiteName))
        return configuration
    }
    
    fileprivate static func ensurePathAvailable(suiteName: String?) {
        if !FileManager.default.fileExists(atPath: applicationBackupRealmPath(suiteName: suiteName)) {
            try? FileManager.default.createDirectory(atPath: applicationBackupRealmPath(suiteName: suiteName), withIntermediateDirectories: true, attributes: [:])
        }
    }
}
