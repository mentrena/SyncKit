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
    public class func cloudKitPrivateSynchronizer(containerName: String, configuration: Realm.Configuration, suiteName: String? = nil) -> QSCloudKitSynchronizer {
        
        ensurePathAvailable(suiteName: suiteName)
        let adapter = RealmSwiftAdapter(persistenceRealmConfiguration: persistenceConfiguration(suiteName: suiteName),
                                                    targetRealmConfiguration: configuration,
                                                    recordZoneID: defaultCustomZoneID())
        let suiteUserDefaults = UserDefaults(suiteName: suiteName)
        let container = CKContainer(identifier: containerName)
        let synchronizer = QSCloudKitSynchronizer(identifier: "DefaultRealmSwiftPrivateSynchronizer",
                                                                          containerIdentifier: containerName,
                                                                          database: container.privateCloudDatabase,
                                                                          adapterProvider: nil,
                                                                          keyValueStore: suiteUserDefaults!)
        synchronizer.addModelAdapter(adapter)
        transferOldServerChangeToken(to: adapter, userDefaults: suiteUserDefaults!, containerName: containerName)
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
        
        ensurePathAvailable(suiteName: suiteName)
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
    
    public class func realmPath(appGroup: String? = nil) -> String {
        
        let url = URL(fileURLWithPath: applicationBackupRealmPath(suiteName: appGroup))
        return url.appendingPathComponent(realmFileName()).path
    }
    
    class func applicationBackupRealmPath(suiteName: String? = nil) -> String {
        
        let rootDirectory: String
        if let suiteName = suiteName {
            rootDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)!.path
        } else {
            rootDirectory = applicationDocumentsDirectory()
        }
        let url = URL(fileURLWithPath: rootDirectory)
        return url.appendingPathComponent("Realm").path
    }
    
    class func applicationDocumentsDirectory() -> String {
        #if TARGET_OS_IPHONE
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last!
        #else
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls.last!.appendingPathComponent("com.mentrena.QSCloudKitSynchronizer").path
        #endif
    }
    
    class func realmFileName() -> String {
        
        return "QSSyncStore.realm"
    }
    
    fileprivate class func persistenceConfiguration(suiteName: String? = nil) -> Realm.Configuration {
        
        var configuration = RealmSwiftAdapter.defaultPersistenceConfiguration()
        configuration.fileURL = URL(fileURLWithPath: realmPath(appGroup: suiteName))
        return configuration
    }
    
    fileprivate class func ensurePathAvailable(suiteName: String?) {
        
        if !FileManager.default.fileExists(atPath: applicationBackupRealmPath(suiteName: suiteName)) {
            try! FileManager.default.createDirectory(atPath: applicationBackupRealmPath(suiteName: suiteName), withIntermediateDirectories: true)
        }
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
