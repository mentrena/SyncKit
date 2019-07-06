//
//  QSCloudKitSynchronizer+Realm.swift
//  Pods
//
//  Created by Manuel Entrena on 01/09/2017.
//
//

import Foundation
import Realm
import CloudKit

extension CloudKitSynchronizer {
    
    /**
     *  Creates a new `QSCloudKitSynchronizer` prepared to work with a Realm model and the SyncKit default record zone in the private database.
     - Parameters:
     - containerName: Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
     - configuration: Configuration of the Realm that is to be tracked and synchronized.
     - suiteName: Identifier of shared App Group for the app. This will store the tracking database in the shared container.
     
     -Returns: A new CloudKit synchronizer for the given realm.
     */
    public class func privateSynchronizer(containerName: String, configuration: RLMRealmConfiguration, suiteName: String? = nil, recordZoneID: CKRecordZone.ID? = nil) -> CloudKitSynchronizer {
        let zoneID = recordZoneID ?? defaultCustomZoneID
        let provider = DefaultRealmAdapterProvider(targetConfiguration: configuration, zoneID: zoneID)
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let container = CKContainer(identifier: containerName)
        let userDefaultsAdapter = UserDefaultsAdapter(userDefaults: userDefaults)
        let synchronizer = CloudKitSynchronizer(identifier: "DefaultRealmPrivateSynchronizer",
                                                containerIdentifier: containerName,
                                                database: DefaultCloudKitDatabaseAdapter(database: container.privateCloudDatabase),
                                                adapterProvider: provider,
                                                keyValueStore: userDefaultsAdapter)
        synchronizer.addModelAdapter(provider.adapter)
        transferOldServerChangeToken(to: provider.adapter, userDefaults: userDefaultsAdapter, containerName: containerName)
        return synchronizer
    }
    
    /**
     *  Creates a new `QSCloudKitSynchronizer` prepared to work with a Realm model and the shared database.
     - Parameters:
     - containerName: Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
     - configuration: Configuration of the Realm that is to be tracked and synchronized.
     - suiteName: Identifier of shared App Group for the app. This will store the tracking database in the shared container.
     
     -Returns: A new CloudKit synchronizer for the given realm.
     */
    public class func sharedSynchronizer(containerName: String, configuration: RLMRealmConfiguration, suiteName: String? = nil) -> CloudKitSynchronizer {
        
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let userDefaultsAdapter = UserDefaultsAdapter(userDefaults: userDefaults)
        let container = CKContainer(identifier: containerName)
        let provider = DefaultRealmProvider(identifier: "DefaultRealmSharedStackProvider",
                                            realmConfiguration: configuration,
                                            appGroup: suiteName)
        let synchronizer = CloudKitSynchronizer(identifier: "DefaultRealmSharedSynchronizer",
                                                containerIdentifier: containerName,
                                                database: DefaultCloudKitDatabaseAdapter(database: container.sharedCloudDatabase),
                                                adapterProvider: provider,
                                                keyValueStore: userDefaultsAdapter)
        
        for adapter in provider.adapterDictionary.values {
            synchronizer.addModelAdapter(adapter)
        }
        return synchronizer
    }
    
    fileprivate class func transferOldServerChangeToken(to adapter: ModelAdapter, userDefaults: KeyValueStore, containerName: String) {
        
        let key = containerName.appending("QSCloudKitFetchChangesServerTokenKey")
        if let encodedToken = userDefaults.object(forKey: key) as? Data {
            
            if let token = NSKeyedUnarchiver.unarchiveObject(with: encodedToken) as? CKServerChangeToken {
                adapter.saveToken(token)
            }
            userDefaults.removeObject(forKey: key)
        }
    }
}
