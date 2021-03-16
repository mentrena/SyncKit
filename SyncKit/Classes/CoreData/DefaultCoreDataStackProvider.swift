//
//  DefaultCoreDataStackProvider.swift
//  SyncKit
//
//  Created by Manuel Entrena on 08/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public extension Notification.Name {
    
    /// Sent when a new Core Data adapter was created
    static let CoreDataStackProviderDidAddAdapterNotification = Notification.Name("QSCoreDataStackProviderDidAddAdapter")
    /// Sent when a Core Data adapter was deleted
    static let CoreDataStackProviderDidRemoveAdapterNotification = Notification.Name("QSCoreDataStackProviderDidRemoveAdapterNotification")
}

@objc public extension NSNotification {
    /// Sent when a new Core Data adapter was created
    static let CoreDataStackProviderDidAddAdapterNotification: NSString = "QSCoreDataStackProviderDidAddAdapterNotification"
    /// Sent when a Core Data adapter was deleted
    static let CoreDataStackProviderDidRemoveAdapterNotification: NSString = "QSCoreDataStackProviderDidRemoveAdapterNotification"
}

/// Can create new Core Data stacks, corresponding to CloudKit record zones. Used by `CloudKitSynchronizer` to dynamically create stacks when new record zones are added to this user's database –e.g. if the user accepts a share.
@objc public class DefaultCoreDataStackProvider: NSObject {
    
    /// This provider's identifier.
    @objc public let identifier: String
    
    /// Core Data store type.
    @objc public let storeType: String
    
    /// Core Data model.
    @objc public let model: NSManagedObjectModel
    
    /// App group, if any.
    @objc public let appGroup: String?
     
    
    /// Current list of adapters maintained by this adapter provider.
    @objc public private(set) var adapterDictionary: [CKRecordZone.ID: CoreDataAdapter]
    
    /// Current list of Core Data stacks maintained by this adapter provider.
    @objc public private(set) var coreDataStacks: [CKRecordZone.ID: CoreDataStack]
    
    
    /// URL of the folder where data by this provider is saved.
    @objc public private(set) var directoryURL: URL!
    
    private static let persistenceFileName = "QSPersistenceStore"
    private static let targetFileName = "QSTargetStore"
    
    
    /// Create a new Core Data stack provider
    /// - Parameters:
    ///   - identifier: Identifier for this provider. Once created, an identifier must remain the same for a given provider
    ///   - storeType: Core Data store type.
    ///   - model: Core Data model.
    ///   - appGroup: Optional app group identifier.
    @objc public init(identifier: String, storeType: String, model: NSManagedObjectModel, appGroup: String? = nil) {
        self.identifier = identifier
        self.storeType = storeType
        self.model = model
        self.appGroup = appGroup
        adapterDictionary = [CKRecordZone.ID: CoreDataAdapter]()
        coreDataStacks = [CKRecordZone.ID: CoreDataStack]()
        super.init()
        directoryURL = stackProviderStoresPath(appGroup: appGroup)
        bringUpDataStacks()
    }
    
    private func bringUpDataStacks() {
        guard let enumerator = FileManager.default.enumerator(at: directoryURL, includingPropertiesForKeys: [.nameKey, .isDirectoryKey], options: .skipsSubdirectoryDescendants) else { return }
        while let subfolderURL = enumerator.nextObject() as? URL {
            let folderName = subfolderURL.lastPathComponent
            let zoneIDComponents = folderName.components(separatedBy: ".zoneID.")
            let zoneID = CKRecordZone.ID(zoneName: zoneIDComponents[0], ownerName: zoneIDComponents[1])
            let stackURL = subfolderURL.appendingPathComponent(DefaultCoreDataStackProvider.targetFileName)
            let persistenceURL = subfolderURL.appendingPathComponent(DefaultCoreDataStackProvider.persistenceFileName)
            let adapter = createAdapter(forCoreDataStackAt: stackURL, persistenceStackAt: persistenceURL, recordZoneID: zoneID)
            adapterDictionary[zoneID] = adapter
        }
    }
    
    private func createAdapter(forCoreDataStackAt storeURL: URL, persistenceStackAt persistenceStoreURL: URL, recordZoneID: CKRecordZone.ID) -> CoreDataAdapter {
        let stack = CoreDataStack(storeType: storeType, model: model, storeURL: storeURL, concurrencyType: .mainQueueConcurrencyType)
        let persistenceStack = CoreDataStack(storeType: NSSQLiteStoreType, model: CoreDataAdapter.persistenceModel, storeURL: persistenceStoreURL, concurrencyType: .privateQueueConcurrencyType)
        let delegate = DefaultCoreDataAdapterDelegate.shared
        let adapter = CoreDataAdapter(persistenceStack: persistenceStack, targetContext: stack.managedObjectContext, recordZoneID: recordZoneID, delegate: delegate)
        coreDataStacks[recordZoneID] = stack
        return adapter
    }
}

extension DefaultCoreDataStackProvider: AdapterProvider {
    public func cloudKitSynchronizer(_ synchronizer: CloudKitSynchronizer, modelAdapterForRecordZoneID zoneID: CKRecordZone.ID) -> ModelAdapter? {
        if let adapter = adapterDictionary[zoneID] {
            return adapter
        }
        
        let folderName = "\(zoneID.zoneName).zoneID.\(zoneID.ownerName)"
        let folderURL = directoryURL.appendingPathComponent(folderName)
        try! FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        let stackURL = folderURL.appendingPathComponent(DefaultCoreDataStackProvider.targetFileName)
        let persistenceURL = folderURL.appendingPathComponent(DefaultCoreDataStackProvider.persistenceFileName)
        
        let adapter = createAdapter(forCoreDataStackAt: stackURL, persistenceStackAt: persistenceURL, recordZoneID: zoneID)
        adapterDictionary[zoneID] = adapter
        NotificationCenter.default.post(name: .CoreDataStackProviderDidAddAdapterNotification, object: self, userInfo: [zoneID: adapter])
        return adapter
    }
    
    public func cloudKitSynchronizer(_ synchronizer: CloudKitSynchronizer, zoneWasDeletedWithZoneID zoneID: CKRecordZone.ID) {
        guard let adapter = adapterDictionary[zoneID] else { return }
        // If the adapter has been synced before
        if adapter.serverChangeToken != nil {
            adapter.deleteChangeTracking()
            if let targetStack = coreDataStacks[zoneID] {
                targetStack.deleteStore()
            }
            
            let folderName = "\(zoneID.zoneName).zoneID.\(zoneID.ownerName)"
            let folderURL = directoryURL.appendingPathComponent(folderName)
            try! FileManager.default.removeItem(at: folderURL)
            
            adapterDictionary.removeValue(forKey: zoneID)
            coreDataStacks.removeValue(forKey: zoneID)
            
            synchronizer.removeModelAdapter(adapter)
            
            NotificationCenter.default.post(name: .CoreDataStackProviderDidRemoveAdapterNotification, object: self, userInfo: [zoneID: adapter])
        }
    }
}

extension DefaultCoreDataStackProvider {
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
    
    private func stackProviderStoresPath(appGroup: String?) -> URL {
        return DefaultCoreDataStackProvider.applicationDocumentsDirectory(appGroup: appGroup).appendingPathComponent("Stores").appendingPathComponent(identifier)
    }
}
