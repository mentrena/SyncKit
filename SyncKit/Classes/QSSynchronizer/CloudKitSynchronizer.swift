//
//  CloudKitSynchronizer.swift
//  Pods
//
//  Created by Manuel Entrena on 05/04/2019.
//

import Foundation
import CloudKit

// For Swift
public extension Notification.Name {
    static let SynchronizerWillSynchronize = Notification.Name("QSCloudKitSynchronizerWillSynchronizeNotification")
    static let SynchronizerWillFetchChanges = Notification.Name("QSCloudKitSynchronizerWillFetchChangesNotification")
    static let SynchronizerWillUploadChanges = Notification.Name("QSCloudKitSynchronizerWillUploadChangesNotification")
    static let SynchronizerDidSynchronize = Notification.Name("QSCloudKitSynchronizerDidSynchronizeNotification")
    static let SynchronizerDidFailToSynchronize = Notification.Name("QSCloudKitSynchronizerDidFailToSynchronizeNotification")
}

// For Obj-C
@objc public extension NSNotification {
    static let CloudKitSynchronizerWillSynchronizeNotification: NSString = "QSCloudKitSynchronizerWillSynchronizeNotification"
    static let CloudKitSynchronizerWillFetchChangesNotification: NSString = "QSCloudKitSynchronizerWillFetchChangesNotification"
    static let CloudKitSynchronizerWillUploadChangesNotification: NSString = "QSCloudKitSynchronizerWillUploadChangesNotification"
    static let CloudKitSynchronizerDidSynchronizeNotification: NSString = "QSCloudKitSynchronizerDidSynchronizeNotification"
    static let CloudKitSynchronizerDidFailToSynchronizeNotification: NSString = "QSCloudKitSynchronizerDidFailToSynchronizeNotification"
}

/**
 A `QSCloudKitSynchronizerAdapterProvider` gets requested for new model adapters when a `QSCloudKitSynchronizer` encounters a new `CKRecordZone` that does not already correspond to an existing model adapter.
 */
@objc
public protocol AdapterProvider {
    /**
     *  The `QSCloudKitSynchronizer` requests a new model adapter for the given record zone.
     *
     *  @param synchronizer `QSCloudKitSynchronizer` asking for the adapter.
     *  @param recordZoneID `CKRecordZoneID` that the model adapter will be used for.
     *
     *  @return ModelAdapter correctly configured to sync changes in the given record zone.
     */
    func cloudKitSynchronizer(_ synchronizer: CloudKitSynchronizer, modelAdapterForRecordZoneID zoneID: CKRecordZone.ID) -> ModelAdapter?
    /**
     *  The `QSCloudKitSynchronizer` informs the provider that a record zone was deleted so it can clean up any associated data.
     *
     *  @param synchronizer `QSCloudKitSynchronizer` that found the deleted record zone.
     *  @param recordZoneID `CKRecordZoneID` of the record zone that was deleted.
     */
    func cloudKitSynchronizer(_ synchronizer: CloudKitSynchronizer, zoneWasDeletedWithZoneID zoneID: CKRecordZone.ID)
}

/**
 A `QSCloudKitSynchronizer` object takes care of making all the required calls to CloudKit to keep your model synchronized, using the provided
 `ModelAdapter` to interact with it.
 `QSCloudKitSynchronizer` will post notifications at different steps of the synchronization process.
 */

public class CloudKitSynchronizer: NSObject {
    
    @objc public enum SyncError: Int, Error {
        /**
         *  Received when synchronize is called while there was an ongoing synchronization.
         */
        case alreadySyncing
        /**
         *  A synchronizer with a higer `compatibilityVersion` value uploaded changes to CloudKit, so those changes won't be imported here.
         *  This error can be detected to prompt the user to update the app to a newer version.
         */
        case higherModelVersionFound
        /**
         *  A record fot the provided object was not found, so the object cannot be shared on CloudKit.
         */
        case recordNotFound
        /**
         *  Synchronization was manually cancelled.
         */
        case cancelled
    }
    
    @objc public enum SynchronizeMode: Int {
        case sync
        case downloadOnly
    }
    
    public static let errorDomain = "CloudKitSynchronizerErrorDomain"
    public static let errorKey = "CloudKitSynchronizerErrorKey"
    
    @objc public let identifier: String
    @objc public let containerIdentifier: String
    public let database: CloudKitDatabaseAdapter
    @objc public let adapterProvider: AdapterProvider
    public let keyValueStore: KeyValueStore
    
    /**
    *  Indicates whether the instance is currently synchronizing data.
    */
    @objc public internal(set) var syncing: Bool = false
    /**
    *  Number of records that are sent in an upload operation.
    */
    @objc public var batchSize: Int = CloudKitSynchronizer.defaultBatchSize
    /**
    *  When set, if the synchronizer finds records uploaded by a different device using a higher compatibility version,
    *   it will end synchronization with a `higherModelVersionFound` error.
    */
    @objc public var compatibilityVersion: Int = 0
    /**
    *  Whether the synchronizer will only download data or also upload any local changes.
    */
    @objc public var syncMode: SynchronizeMode = .sync
    
    internal let dispatchQueue = DispatchQueue(label: "QSCloudKitSynchronizer")
    internal let operationQueue = OperationQueue()
    internal var modelAdapterDictionary = [CKRecordZone.ID: ModelAdapter]()
    internal var serverChangeToken: CKServerChangeToken?
    internal var activeZoneTokens = [CKRecordZone.ID: CKServerChangeToken]()
    internal var cancelSync = false
    internal var completion: ((Error?) -> ())?
    internal weak var currentOperation: Operation?
    
    internal static let defaultBatchSize = 200
    static let deviceUUIDKey = "QSCloudKitDeviceUUIDKey"
    static let modelCompatibilityVersionKey = "QSCloudKitModelCompatibilityVersionKey"
    
    /**
     *  Initializes a newly allocated synchronizer.
     *
     *  @param identifier Identifier for the `QSCloudKitSynchronizer`.
     *  @param containerIdentifier Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
     *  @param database            Private or Shared CloudKit Database
     *  @param adapterProvider      QSCloudKitSynchronizerAdapterProvider
     *  @param keyValueStore       Object conforming to QSKeyValueStore (NSUserDefaults, for example)
     *
     *  @return Initialized synchronizer or `nil` if no iCloud container can be found with the provided identifier.
     */
    
    @objc public init(identifier: String, containerIdentifier: String, database: CloudKitDatabaseAdapter, adapterProvider: AdapterProvider, keyValueStore: KeyValueStore = UserDefaultsAdapter(userDefaults: UserDefaults.standard)) {
        self.identifier = identifier
        self.containerIdentifier = containerIdentifier
        self.adapterProvider = adapterProvider
        self.database = database
        self.keyValueStore = keyValueStore
        super.init()
        
        BackupDetection.runBackupDetection { (result, error) in
            if result == .restoredFromBackup {
                self.clearDeviceIdentifier()
            }
        }
        
    }
    
    fileprivate var _deviceIdentifier: String!
    var deviceIdentifier: String {
        if _deviceIdentifier == nil {
            _deviceIdentifier = deviceUUID
            if _deviceIdentifier == nil {
                _deviceIdentifier = UUID().uuidString
                deviceUUID = _deviceIdentifier
            }
        }
        return _deviceIdentifier
    }
    
    func clearDeviceIdentifier() {
        deviceUUID = nil
    }
    
    // MARK: - Public
    
    /**
    *  These keys will be added to CKRecords uploaded to CloudKit and are used by SyncKit internally.
    */
    public static let metadataKeys: [String] = [CloudKitSynchronizer.deviceUUIDKey, CloudKitSynchronizer.modelCompatibilityVersionKey]
    
    /**
     *  Synchronize data with CloudKit.
     *  @return Error. Could be a SyncError, CKError, or any other error found during synchronization.
     */
    @objc
    public func synchronize(completion: ((Error?) -> ())?) {
        guard !syncing else {
            completion?(SyncError.alreadySyncing)
            return
        }
        
        debugPrint("CloudKitSynchronizer >> Initiating synchronization")
        cancelSync = false
        syncing = true
        self.completion = completion
        performSynchronization()
    }
    
    /**
    *  Cancel synchronization. It will cause a current synchronization to end with a `cancelled` error.
    */
    @objc
    public func cancelSynchronization() {
        guard syncing, !cancelSync else { return }
        
        cancelSync = true
        currentOperation?.cancel()
    }
    
    /**
    *  Deletes saved database token, so next synchronization will include changes in all record zones in the database.
    * This does not reset tokens stored by model adapters.
    */
    @objc
    public func resetDatabaseToken() {
        storedDatabaseToken = nil
    }
    
    /**
    * Deletes saved database token and all local metadata used to track changes in models.
    * The synchronizer should not be used after calling this function, create a new synchronizer instead if you need it.
    */
    @objc
    public func eraseLocalMetadata() {

        cancelSynchronization()
        dispatchQueue.async {
            self.storedDatabaseToken = nil
            self.clearAllStoredSubscriptionIDs()
            self.deviceUUID = nil
            self.modelAdapters.forEach {
                $0.deleteChangeTracking()
                self.removeModelAdapter($0)
            }
        }
    }
    
    /**
    * Deletes the corresponding record zone on CloudKit, along with any data in it.
    */
    @objc
    public func deleteRecordZone(for adapter: ModelAdapter, completion: ((Error?)->())?) {
        database.delete(withRecordZoneID: adapter.recordZoneID) { (zoneID, error) in
            if let error = error {
                debugPrint("CloudKitSynchronizer >> Error: \(error)")
            } else {
                debugPrint("CloudKitSynchronizer >> Deleted zone: \(zoneID?.debugDescription ?? "")")
            }
            completion?(error)
        }
    }
    
    /**
    * Model adapters in use by this synchronizer.
    */
    @objc
    public var modelAdapters: [ModelAdapter] {
        return Array(modelAdapterDictionary.values)
    }
    
    /**
    * Adds a new model adapter to be synchronized with CloudKit.
    */
    @objc
    public func addModelAdapter(_ adapter: ModelAdapter) {
        modelAdapterDictionary[adapter.recordZoneID] = adapter
    }
    
    /**
    * Removes the model adapter so data managed by it won't be synced with CloudKit any more.
    */
    @objc 
    public func removeModelAdapter(_ adapter: ModelAdapter) {
        modelAdapterDictionary.removeValue(forKey: adapter.recordZoneID)
    }
}
