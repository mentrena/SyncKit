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
    
    /**
     *  Creates a new `QSCloudKitSynchronizer` prepared to work with a Realm model and the SyncKit default record zone in the private database.
     - Parameters:
     - containerName: Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
     - configuration: Configuration of the Realm that is to be tracked and synchronized.
     - suiteName: Identifier of shared App Group for the app. This will store the tracking database in the shared container.
     
     -Returns: A new CloudKit synchronizer for the given realm.
     */
    public class func cloudKitPrivateSynchronizer(containerName: String, configuration: Realm.Configuration, suiteName: String? = nil, recordZoneID: CKRecordZone.ID = defaultCustomZoneID()) -> QSCloudKitSynchronizer {
        
        let provider = DefaultRealmSwiftAdapterProvider(targetConfiguration: configuration, zoneID: recordZoneID)
        let suiteUserDefaults = UserDefaults(suiteName: suiteName)
        let container = CKContainer(identifier: containerName)
        let synchronizer = QSCloudKitSynchronizer(identifier: "DefaultRealmSwiftPrivateSynchronizer",
                                                                          containerIdentifier: containerName,
                                                                          database: container.privateCloudDatabase,
                                                                          adapterProvider: provider,
                                                                          keyValueStore: suiteUserDefaults!)
        synchronizer.addModelAdapter(provider.adapter)
        transferOldServerChangeToken(to: provider.adapter, userDefaults: suiteUserDefaults!, containerName: containerName)
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
    public class func cloudKitSharedSynchronizer(containerName: String, configuration: Realm.Configuration, suiteName: String? = nil) -> QSCloudKitSynchronizer {
        
        let suiteUserDefaults = UserDefaults(suiteName: suiteName)
        let container = CKContainer(identifier: containerName)
        let provider = DefaultRealmProvider(identifier: "DefaultRealmSwiftSharedStackProvider",
                                            realmConfiguration: configuration,
                                            appGroup: suiteName)
        let synchronizer = QSCloudKitSynchronizer(identifier: "DefaultRealmSwiftSharedSynchronizer",
                                                  containerIdentifier: containerName,
                                                  database: container.sharedCloudDatabase,
                                                  adapterProvider: provider,
                                                  keyValueStore: suiteUserDefaults!)
        
        for adapter in provider.adapterDictionary.values {
            synchronizer.addModelAdapter(adapter)
        }
        return synchronizer
    }
    
    fileprivate class func transferOldServerChangeToken(to adapter: QSModelAdapter, userDefaults: UserDefaults, containerName: String) {
        
        let key = containerName.appending("QSCloudKitFetchChangesServerTokenKey")
        if let encodedToken = userDefaults.object(forKey: key) as? Data {
            
            if let token = NSKeyedUnarchiver.unarchiveObject(with: encodedToken) as? CKServerChangeToken {
                adapter.save(token)
            }
            userDefaults.removeObject(forKey: key)
        }
    }
}
