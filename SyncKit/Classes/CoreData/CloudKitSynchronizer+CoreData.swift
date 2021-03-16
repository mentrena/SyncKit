//
//  CloudKitSynchronizer+CoreData.swift
//  Pods
//
//  Created by Manuel Entrena on 22/06/2019.
//

import Foundation
import CoreData
import CloudKit

extension CloudKitSynchronizer {
    
    
    /// Creates a new, default synchronizer for the user's private database
    /// - Parameters:
    ///   - containerName: CloudKit container name.
    ///   - managedObjectContext: `NSManagedObject` that should be used for synchronization. Changes in it will be uploaded and downloaded to/from CloudKit.
    ///   - suiteName: App suite, if this app is part of one. If provided, synchronizer's state will be saved in the app group.
    ///   - recordZoneID: `CKRecordZoneID` to be used for synchronization. If not provided, default value will be `CKRecordZone.ID(zoneName: "QSCloudKitCustomZoneName", ownerName: CKCurrentUserDefaultName)`.
    /// - Returns: A fully configured `CloudKitSynchronizer` for the private database.
    @objc public static func privateSynchronizer(containerName: String,
                                           managedObjectContext: NSManagedObjectContext,
                                           suiteName: String? = nil,
                                           recordZoneID: CKRecordZone.ID? = nil) -> CloudKitSynchronizer {
        let zoneID = recordZoneID ?? CloudKitSynchronizer.defaultCustomZoneID
        let adapterProvider = DefaultCoreDataAdapterProvider(managedObjectContext: managedObjectContext,
                                                             zoneID: zoneID,
                                                             appGroup: suiteName)
        let userDefaults: UserDefaults! = suiteName != nil ? UserDefaults(suiteName: suiteName!) : UserDefaults.standard
        let container = CKContainer(identifier: containerName)
        let userDefaultsAdapter = UserDefaultsAdapter(userDefaults: userDefaults)
        let synchronizer = CloudKitSynchronizer(identifier: "DefaultCoreDataPrivateSynchronizer",
                                                containerIdentifier: containerName,
                                                database: DefaultCloudKitDatabaseAdapter(database: container.privateCloudDatabase),
                                                adapterProvider: adapterProvider,
                                                keyValueStore: userDefaultsAdapter)
        synchronizer.addModelAdapter(adapterProvider.adapter)
        
        transferOldServerChangeToken(to: adapterProvider.adapter,
                                     userDefaults: userDefaultsAdapter,
                                     containerName: containerName)
        
        return synchronizer
    }
    
    
    /// Creates a new, default synchronizer for the user's shared database.
    /// - Parameters:
    ///   - containerName: CloudKit container name.
    ///   - objectModel: `NSManagedObjectModel` that is used for synchronization.
    ///   - suiteName: App suite, if this app is part of one. If provided, synchronizer's state will be saved in the app group.
    /// - Returns: A fully configured `CloudKitSynchronizer` for the shared database.
    @objc public static func sharedSynchronizer(containerName: String,
                                          objectModel: NSManagedObjectModel,
                                          suiteName: String? = nil) -> CloudKitSynchronizer {
        let provider = DefaultCoreDataStackProvider(identifier: "DefaultCoreDataSharedStackProvider",
                                                    storeType: NSSQLiteStoreType,
                                                    model: objectModel,
                                                    appGroup: suiteName)
        let userDefaults: UserDefaults! = suiteName != nil ? UserDefaults(suiteName: suiteName!) : UserDefaults.standard
        let container = CKContainer(identifier: containerName)
        let synchronizer = CloudKitSynchronizer(identifier: "DefaultCoreDataSharedSynchronizer",
                                                containerIdentifier: containerName,
                                                database: DefaultCloudKitDatabaseAdapter(database: container.sharedCloudDatabase),
                                                adapterProvider: provider,
                                                keyValueStore: UserDefaultsAdapter(userDefaults: userDefaults))
        provider.adapterDictionary.forEach { (_, adapter) in
            synchronizer.addModelAdapter(adapter)
        }
        return synchronizer
    }
    
    private static func transferOldServerChangeToken(to adapter: ModelAdapter, userDefaults: KeyValueStore, containerName: String) {
        let key = containerName.appending("QSCloudKitFetchChangesServerTokenKey")
        if let encodedToken = userDefaults.object(forKey: key) as? Data,
            let token: CKServerChangeToken = QSCoder.shared.object(from: encodedToken) as? CKServerChangeToken {
            adapter.saveToken(token)
            userDefaults.removeObject(forKey: key)
        }
    }
    
    
    /// List of `NSManagedObjectContext` kept in sync by the synchronizer. Usually just the one you provided, for the default private synchronizer, but the shared synchronizer will have one Core Data context for each record zone shared with this user.
    @objc public var contexts: [NSManagedObjectContext] {
        if let provider = adapterProvider as? DefaultCoreDataAdapterProvider {
            return [provider.managedObjectContext]
        } else if let provider = adapterProvider as? DefaultCoreDataStackProvider {
            return provider.coreDataStacks.compactMap { $0.value.managedObjectContext }
        }
        return []
    }
    
    
    /// Creates a multiFetchedResultsController to simplify dealing with results from multiple `NSManagedObjectContext` instances.
    /// - Parameter fetchRequest: Fetch request to be applied to managed contexts.
    /// - Returns: Configured controller.
    /// This controller can be particularly useful to retrieve data from a shared synchronizer, as it will potentially be coming from multiple `NSManagedObjectContext`s.
    public func multiFetchedResultsController(fetchRequest: NSFetchRequest<NSFetchRequestResult>) -> CoreDataMultiFetchedResultsController? {
        guard let provider = adapterProvider as? DefaultCoreDataStackProvider else {
            return nil
        }
        return CoreDataMultiFetchedResultsController(stackProvider: provider, fetchRequest: fetchRequest)
    }
}
