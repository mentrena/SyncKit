//
//  QSDefaultCoreDataAdapterProvider.swift
//  Pods
//
//  Created by Manuel Entrena on 18/11/2018.
//

import Foundation
import CloudKit

@objc public class QSDefaultCoreDataAdapterProvider: NSObject, QSCloudKitSynchronizerAdapterProvider {
    
    let zoneID: CKRecordZone.ID
    let managedObjectContext: NSManagedObjectContext
    let appGroup: String?
    @objc public private(set) var adapter: QSCoreDataAdapter!
    
    @objc public init(managedObjectContext: NSManagedObjectContext, zoneID: CKRecordZone.ID, appGroup: String? = nil) {
        self.managedObjectContext = managedObjectContext
        self.zoneID = zoneID
        self.appGroup = appGroup
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
    
    fileprivate func createAdapter() -> QSCoreDataAdapter {
        
        let delegate = QSDefaultCoreDataAdapterDelegate.sharedInstance()
        let stack = QSCoreDataStack(storeType: NSSQLiteStoreType, model: QSCoreDataAdapter.persistenceModel(), storePath: QSDefaultCoreDataAdapterProvider.storePath(appGroup: appGroup))
        
        return QSCoreDataAdapter(persistenceStack: stack, targetContext: managedObjectContext, recordZoneID: zoneID, delegate: delegate)
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
    
    @objc public static func storePath(appGroup: String?) -> String {
        return applicationStoresPath(appGroup: appGroup).appending(storeFileName())
    }
    
    private static func applicationDocumentsDirectory() -> String {
        
        #if os(iOS)
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last!
        #else
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls.last!.appendingPathComponent("com.mentrena.QSCloudKitSynchronizer").path
        #endif
    }
    
    private static func applicationDocumentsDirectory(_ appGroup: String?) -> String {
        
        if let appGroup = appGroup {
            return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)!.path
        } else {
            return applicationDocumentsDirectory()
        }
    }
    
    private static func applicationStoresPath(appGroup: String?) -> String {
        let documentsDirectory = QSDefaultCoreDataAdapterProvider.applicationDocumentsDirectory(appGroup) as NSString
        return documentsDirectory.appendingPathComponent("Stores")
    }
    
    private static func storeFileName() -> String {
        return "QSSyncStore"
    }
}
