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

@objc public protocol DefaultCoreDataStackProviderDelegate: class {
    func provider(_ provider: DefaultCoreDataStackProvider, didAddAdapter adapter: CoreDataAdapter, forZoneID zoneID: CKRecordZone.ID)
    func provider(_ provider: DefaultCoreDataStackProvider, didRemoveAdapterForZoneID zoneID: CKRecordZone.ID)
}

@objc public class DefaultCoreDataStackProvider: NSObject {
    
    @objc public let identifier: String
    @objc public let storeType: String
    @objc public let model: NSManagedObjectModel
    @objc public let appGroup: String?
    
    @objc public weak var delegate: DefaultCoreDataStackProviderDelegate?
    
    @objc public private(set) var adapterDictionary: [CKRecordZone.ID: CoreDataAdapter]
    @objc public private(set) var coreDataStacks: [CKRecordZone.ID: CoreDataStack]
    @objc public private(set) var directoryURL: URL!
    
    private static let persistenceFileName = "QSPersistenceStore"
    private static let targetFileName = "QSTargetStore"
    
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
        delegate?.provider(self, didAddAdapter: adapter, forZoneID: zoneID)
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
            
            delegate?.provider(self, didRemoveAdapterForZoneID: zoneID)
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
