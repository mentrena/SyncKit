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
    
    public func multiFetchedResultsController(fetchRequest: NSFetchRequest<NSFetchRequestResult>) -> CoreDataMultiFetchedResultsController? {
        guard let provider = adapterProvider as? DefaultCoreDataStackProvider else {
            return nil
        }
        return CoreDataMultiFetchedResultsController(stackProvider: provider, fetchRequest: fetchRequest)
    }
}
