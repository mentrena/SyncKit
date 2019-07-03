//
//  DefaultCoreDataAdapterProvider.swift
//  Pods
//
//  Created by Manuel Entrena on 22/06/2019.
//

import Foundation
import CloudKit
import CoreData

@objc public class DefaultCoreDataAdapterProvider: NSObject, AdapterProvider {
    
    @objc public let zoneID: CKRecordZone.ID
    @objc public let managedObjectContext: NSManagedObjectContext
    @objc public let appGroup: String?
    @objc public private(set) var adapter: CoreDataAdapter!
    
    @objc public init(managedObjectContext: NSManagedObjectContext, zoneID: CKRecordZone.ID, appGroup: String? = nil) {
        self.managedObjectContext = managedObjectContext
        self.zoneID = zoneID
        self.appGroup = appGroup
        super.init()
        adapter = createAdapter()
    }
    
    public func cloudKitSynchronizer(_ synchronizer: CloudKitSynchronizer, modelAdapterForRecordZoneID recordZoneID: CKRecordZone.ID) -> ModelAdapter? {
        
        guard recordZoneID == zoneID else { return nil }
        
        return adapter
    }
    
    public func cloudKitSynchronizer(_ synchronizer: CloudKitSynchronizer, zoneWasDeletedWithZoneID recordZoneID: CKRecordZone.ID) {
        
        let adapterHasSyncedBefore = adapter.serverChangeToken != nil
        if recordZoneID == zoneID && adapterHasSyncedBefore {
            
            adapter.deleteChangeTracking()
            synchronizer.removeModelAdapter(adapter)
            
            adapter = createAdapter()
            synchronizer.addModelAdapter(adapter)
        }
    }
    
    fileprivate func createAdapter() -> CoreDataAdapter {
        
        let delegate = DefaultCoreDataAdapterDelegate.shared
        let stack = CoreDataStack(storeType: NSSQLiteStoreType,
                                  model: CoreDataAdapter.persistenceModel,
                                  storeURL: DefaultCoreDataAdapterProvider.storeURL(appGroup: appGroup))
        
        return CoreDataAdapter(persistenceStack: stack, targetContext: managedObjectContext, recordZoneID: zoneID, delegate: delegate)
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
    
    public static func storeURL(appGroup: String?) -> URL {
        return applicationStoresPath(appGroup: appGroup).appendingPathComponent(storeFileName())
    }
    
    private static func applicationDocumentsDirectory() -> URL {
        #if os(iOS) || os(watchOS)
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).last!
        #else
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls.last!.appendingPathComponent("com.mentrena.QSCloudKitSynchronizer")
        #endif
    }
    
    private static func applicationDocumentsDirectory(appGroup: String?) -> URL {
        if let appGroup = appGroup {
            return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)!
        }
        return applicationDocumentsDirectory()
    }
    
    private static func applicationStoresPath(appGroup: String?) -> URL {
        return DefaultCoreDataAdapterProvider.applicationDocumentsDirectory(appGroup: appGroup).appendingPathComponent("Stores")
    }
    
    private static func storeFileName() -> String {
        return "QSSyncStore"
    }
}
