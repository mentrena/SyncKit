//  Converted to Swift 4 by Swiftify v4.1.6781 - https://objectivec2swift.com/
//
//  QSCloudKitHelper.h
//  Quikstudy
//
//  Created by Manuel Entrena on 26/05/2016.
//  Copyright © 2016 Manuel Entrena. All rights reserved.
//
//
//  QSCloudKitHelper.m
//  Quikstudy
//
//  Created by Manuel Entrena on 26/05/2016.
//  Copyright © 2016 Manuel Entrena. All rights reserved.
//

import CloudKit
import Foundation

let QSCloudKitSynchronizerErrorDomain = ""
enum QSCloudKitSynchronizerErrorCode : Int {
    case qsCloudKitSynchronizerErrorAlreadySyncing
    case qsCloudKitSynchronizerErrorHigherModelVersionFound
    case qsCloudKitSynchronizerErrorCancelled
}

enum QSCloudKitSynchronizeMode : Int {
    case sync
    case download
}

/**
 *  Posted whenever a synchronizer begins a synchronization.
    The notification object is the synchronizer.
 */
let QSCloudKitSynchronizerWillSynchronizeNotification = ""
/**
 *  Posted before a synchronizer asks CloudKit for any changes to download.
    The notification object is the synchronizer.
 */
let QSCloudKitSynchronizerWillFetchChangesNotification = ""
/**
 *  Posted before a synchronizer sends local changes to CloudKit.
    The notification object is the synchronizer.
 */
let QSCloudKitSynchronizerWillUploadChangesNotification = ""
/**
 *  Posted whenever a synchronizer finishes a synchronization.
    The notification object is the synchronizer.
 */
let QSCloudKitSynchronizerDidSynchronizeNotification = ""
/**
 *  Posted whenever a synchronizer finishes a synchronization with an error.
    The notification object is the synchronizer.
 
    The <i>userInfo</i> dictionary contains the error under the <i>QSCloudKitSynchronizerErrorKey</i> key
 */
let QSCloudKitSynchronizerDidFailToSynchronizeNotification = ""
/**
 *  Key inside any notification user info dictionary that will provide the underlying CloudKit error.
 */
let QSCloudKitSynchronizerErrorKey = ""
func callBlockIfNotNil(block: Any, ...: Any) {
    if block {
        block(__VA_ARGS__)
    }
}
let QSCloudKitSynchronizerErrorDomain = "QSCloudKitSynchronizerErrorDomain"
let QSCloudKitSynchronizerWillSynchronizeNotification = "QSCloudKitSynchronizerWillSynchronizeNotification"
let QSCloudKitSynchronizerWillFetchChangesNotification = "QSCloudKitSynchronizerWillFetchChangesNotification"
let QSCloudKitSynchronizerWillUploadChangesNotification = "QSCloudKitSynchronizerWillUploadChangesNotification"
let QSCloudKitSynchronizerDidSynchronizeNotification = "QSCloudKitSynchronizerDidSynchronizeNotification"
let QSCloudKitSynchronizerDidFailToSynchronizeNotification = "QSCloudKitSynchronizerDidFailToSynchronizeNotification"
let QSCloudKitSynchronizerErrorKey = "QSCloudKitSynchronizerErrorKey"
private let QSDefaultBatchSize: Int = 100
let QSCloudKitDeviceUUIDKey = "QSCloudKitDeviceUUIDKey"
let QSCloudKitModelCompatibilityVersionKey = "QSCloudKitModelCompatibilityVersionKey"

/**
    A `QSCloudKitSynchronizerAdapterProvider` gets requested for new model adapters when a `QSCloudKitSynchronizer` encounters a new `CKRecordZone` that does not already correspond to an existing model adapter.
 */
protocol QSCloudKitSynchronizerAdapterProvider: class {
    /**
     *  The `QSCloudKitSynchronizer` requests a new model adapter for the given record zone.
     *
     *  @param synchronizer `QSCloudKitSynchronizer` asking for the adapter.
     *  @param recordZoneID `CKRecordZoneID` that the model adapter will be used for.
     *
     *  @return QSModelAdapter correctly configured to sync changes in the given record zone.
     */
    func cloudKitSynchronizer(_ synchronizer: QSCloudKitSynchronizer, modelAdapterFor recordZoneID: CKRecordZoneID) -> QSModelAdapter?

    /**
     *  The `QSCloudKitSynchronizer` informs the provider that a record zone was deleted so it can clean up any associated data.
     *
     *  @param synchronizer `QSCloudKitSynchronizer` that found the deleted record zone.
     *  @param recordZoneID `CKRecordZoneID` of the record zone that was deleted.
     */
    func cloudKitSynchronizer(_ synchronizer: QSCloudKitSynchronizer, zoneWasDeletedWith recordZoneID: CKRecordZoneID)
}

/**
    A `QSCloudKitSynchronizer` object takes care of making all the required calls to CloudKit to keep your model synchronized, using the provided
    `QSModelAdapter` to interact with it.
    `QSCloudKitSynchronizer` will post notifications at different steps of the synchronization process.
 */
class QSCloudKitSynchronizer: NSObject {
    /**
     *  A unique identifier used for this synchronizer. It is used for some state-preservation.
     */

    private(set) var identifier = ""
    /**
     *  The identifier of the iCloud container used for synchronization. (read-only)
     */
    private(set) var containerIdentifier = ""
    /**
     *  Indicates whether the synchronizer is currently performing a synchronization. (read-only)
     */
    private(set) var syncing = false
    /**
     *  Maximum number of items that will be included in an upload to CloudKit. (read-only)
     */
    private(set) var batchSize: Int = 0
    /**
     *  If the version is set (!= 0) and the synchronizer downloads records with a higher version then
     *  synchronization will end with the appropriate error.
     */
    var compatibilityVersion: Int = 0
    /**
     *  Sync mode: full sync or download only
     */
    var syncMode: QSCloudKitSynchronizeMode?
    /**
     *  CloudKit database.
     */
    private(set) var database: CKDatabase!
    /**
     *  Adapter provider, to dynamically provide a new model adapter when a new record zone is found in the assigned cloudKit database.
     */
    private(set) weak var adapterProvider: QSCloudKitSynchronizerAdapterProvider?
    /**
     *  A key-value store for some state-preservation.
     */
    private(set) weak var keyValueStore: QSKeyValueStore?

    private var _serverChangeToken: CKServerChangeToken?
    private var serverChangeToken: CKServerChangeToken? {
        get {
            if _serverChangeToken == nil {
                _serverChangeToken = getStoredDatabaseToken()
            }
            return _serverChangeToken
        }
        set(serverChangeToken) {
            _serverChangeToken = serverChangeToken
            storeDatabaseToken(serverChangeToken)
        }
    }
    private var activeZoneTokens: [AnyHashable : Any] = [:]
    private var usesSharedDatabase = false
    private var modelAdapterDictionary: [AnyHashable : Any] = [:]
    private var _deviceIdentifier = ""
    private var deviceIdentifier: String {
        if _deviceIdentifier == "" {
                _deviceIdentifier = getStoredDeviceUUID()
                if _deviceIdentifier == "" {
                    let UUID = UUID()
                    _deviceIdentifier = UUID.uuidString
                    storeDeviceUUID(_deviceIdentifier)
                }
            }
            return _deviceIdentifier
    }
    private var cancelSync = false
    private var completion: ((_ error: Error?) -> Void)?
    private weak var currentOperation: Operation?
    private var dispatchQueue: DispatchQueue?
    private var operationQueue: OperationQueue?

    /**
     *  Array of keys added to `CKRecord` objects by the `QSCloudKitSynchronizer`. These keys should be ignored by model adapters when applying changes from `CKRecord` to model objects.
     */
    class func synchronizerMetadataKeys() -> [String]? {
        var metadataKeys: [Any]? = nil
        var onceToken: Int = 0
        if (onceToken == 0) {
            metadataKeys = [QSCloudKitDeviceUUIDKey, QSCloudKitModelCompatibilityVersionKey]
        }
        onceToken = 1
        return metadataKeys as? [String]
    }

    /**
     *  All the model adapters currently being synced by this `QSCloudKitSynchronizer`
     */
    func modelAdapters() -> [QSModelAdapter?]? {
        return modelAdapterDictionary.allValues as? [QSModelAdapter?]
    }

    /**
     *  Adds a new model adapter for syncing.
     */
    func add(_ modelAdapter: QSModelAdapter?) {
        var updatedManagers = modelAdapterDictionary
        if let anID = modelAdapter?.recordZoneID, let anAdapter = modelAdapter {
            updatedManagers[anID] = anAdapter
        }
        modelAdapterDictionary = updatedManagers
    }

    /**
     *  Removed a model adapter from this synchronizer.
     */
    func remove(_ modelAdapter: QSModelAdapter?) {
        var updatedManagers = modelAdapterDictionary
        updatedManagers.removeValueForKey(modelAdapter?.recordZoneID)
        modelAdapterDictionary = updatedManagers
    }

    /**
     *  Initializes a newly allocated synchronizer.
     *
     *  @param identifier Identifier for the `QSCloudKitSynchronizer`.
     *  @param containerIdentifier Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
     *  @param database            Private or Shared CloudKit Database
     *  @param adapterProvider            QSCloudKitSynchronizerAdapterProvider
     *
     *  @return Initialized synchronizer or `nil` if no iCloud container can be found with the provided identifier.
     */
    convenience init(identifier: String?, containerIdentifier: String?, database: CKDatabase?, adapterProvider: QSCloudKitSynchronizerAdapterProvider?) {
        _init(withIdentifier: identifier, containerIdentifier: containerIdentifier, database: database, adapterProvider: adapterProvider, keyValueStore: UserDefaults.standard)
    }

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
    convenience init(identifier: String?, containerIdentifier: String?, database: CKDatabase?, adapterProvider: QSCloudKitSynchronizerAdapterProvider?, keyValueStore: QSKeyValueStore?) {
        _init(withIdentifier: identifier, containerIdentifier: containerIdentifier, database: database, adapterProvider: adapterProvider, keyValueStore: keyValueStore)
    }

    /**
     *  Performs synchronization with CloudKit.
     *
     *  @param completion A block that will be called after synchronization ends. The block will receive an `NSError` if an error happened during synchronization.
     */
    func synchronize(withCompletion completion: @escaping (_ error: Error?) -> Void) {
        if syncing {
            callBlockIfNotNil(completion, NSError(domain: QSCloudKitSynchronizerErrorDomain, code: QSCloudKitSynchronizerErrorCode.qsCloudKitSynchronizerErrorAlreadySyncing.rawValue, userInfo: nil))
            return
        }
        DLog("QSCloudKitSynchronizer >> Initiating synchronization")
        cancelSync = false
        syncing = true
        self.completion = completion
        performSynchronization()
    }

    /**
     *  Cancel an ongoing synchronization.
     */
    func cancelSynchronization() {
        if syncing {
            cancelSync = true
            currentOperation?.cancel()
        }
    }

    /**
     *  Erase all local change tracking to stop synchronizing.
     */
    func eraseLocal() {
        storeDatabaseToken(nil)
        clearAllStoredSubscriptionIDs()
        storeDeviceUUID(nil)
        for modelAdapter: QSModelAdapter? in modelAdapters() ?? [QSModelAdapter?]() {
            modelAdapter?.deleteChangeTracking()
        }
    }

    /**
     *  Erase all data currently in CloudKit for this change manager. This will delete the `CKRecordZone` that was used by the change manager.
     */
    func eraseRemoteAndLocalData(for modelAdapter: QSModelAdapter?, withCompletion completion: @escaping (_ error: Error?) -> Void) {
        if let anID = modelAdapter?.recordZoneID {
            database.delete(withRecordZoneID: anID, completionHandler: { zoneID, error in
                if error == nil {
                    DLog("QSCloudKitSynchronizer >> Deleted zone: %@", zoneID)
                    modelAdapter?.deleteChangeTracking()
                    self.remove(modelAdapter)
                } else {
                    DLog("QSCloudKitSynchronizer >> Error: %@", error)
                }
                callBlockIfNotNil(completion, error)
            })
        }
    }

// MARK: - Public

    func _init(withIdentifier identifier: String?, containerIdentifier: String?, database: CKDatabase?, adapterProvider: QSCloudKitSynchronizerAdapterProvider?, keyValueStore: QSKeyValueStore?) -> QSCloudKitSynchronizer {
        super.init()
        
        self.identifier = identifier ?? ""
        self.adapterProvider = adapterProvider
        self.keyValueStore = keyValueStore
        self.containerIdentifier = containerIdentifier ?? ""
        modelAdapterDictionary = [:]
        batchSize = QSDefaultBatchSize
        compatibilityVersion = 0
        syncMode = .sync
        if let aDatabase = database {
            self.database = aDatabase
        }
        QSBackupDetection.run(withCompletion: { result, error in
            if result == QSBackupDetectionResultRestoredFromBackup {
                self.clearDeviceIdentifier()
            }
        })
        dispatchQueue = DispatchQueue(label: "QSCloudKitSynchronizer")
        operationQueue = OperationQueue()
    
        return self
    }

    func clearDeviceIdentifier() {
        storeDeviceUUID(nil)
    }

// MARK: - Sync
    func performSynchronization() {
        dispatchQueue.async(execute: {
            DispatchQueue.main.async(execute: {
                NotificationCenter.default.post(name: NSNotification.Name(QSCloudKitSynchronizerWillSynchronizeNotification), object: self)
            })
            for modelAdapter: QSModelAdapter? in self.modelAdapters() ?? [QSModelAdapter?]() {
                modelAdapter?.prepareForImport()
            }
            self.synchronizationFetchChanges()
        })
    }

// MARK: - 1) Fetch changes
    func synchronizationFetchChanges() {
        if cancelSync {
            try? self.finishSynchronization()
        } else {
            DispatchQueue.main.async(execute: {
                NotificationCenter.default.post(name: NSNotification.Name(QSCloudKitSynchronizerWillFetchChangesNotification), object: self)
            })
            fetchDatabaseChanges(withCompletion: { databaseToken, error in
                if error != nil {
                    try? self.finishSynchronization()
                } else {
                    self.serverChangeToken = databaseToken
                    if self.syncMode == .sync {
                        self.synchronizationUploadChanges()
                    } else {
                        try? self.finishSynchronization()
                    }
                }
            })
        }
    }

    func fetchDatabaseChanges(withCompletion completion: @escaping (_ databaseToken: CKServerChangeToken?, _ error: Error?) -> Void) {
        let operation = QSFetchDatabaseChangesOperation(database: database, databaseToken: serverChangeToken) { databaseToken, changedZoneIDs, deletedZoneIDs in
                self.dispatchQueue.async(execute: {
                    self.notifyProvider(forDeletedZoneIDs: deletedZoneIDs)
                    if changedZoneIDs.count != 0 {
                        self.loadTokens(forZoneIDs: changedZoneIDs)
                        let toFetchZoneIDs = self.filteredZoneIDs(changedZoneIDs, managedByManagerIn: self.modelAdapters())
                        self.fetchZoneChanges(toFetchZoneIDs, withCompletion: {
                            self.synchronizationMergeChanges(withCompletion: { error in
                                self.resetActiveTokens()
                                callBlockIfNotNil(completion, databaseToken, error)
                            })
                        })
                    } else {
                        callBlockIfNotNil(completion, databaseToken, nil)
                    }
                })
            }
        run(operation)
    }

    func loadTokens(forZoneIDs zoneIDs: [Any]?) {
        activeZoneTokens = [AnyHashable : Any]()
        for zoneID: CKRecordZoneID? in zoneIDs as? [CKRecordZoneID?] ?? [CKRecordZoneID?]() {
            var modelAdapter: QSModelAdapter? = nil
            if let anID = zoneID {
                modelAdapter = modelAdapterDictionary[anID] as? QSModelAdapter
            }
            if modelAdapter == nil {
                var newModelAdapter: QSModelAdapter? = nil
                if let anID = zoneID {
                    newModelAdapter = adapterProvider?.cloudKitSynchronizer(self, modelAdapterFor: anID)
                }
                if newModelAdapter != nil {
                    modelAdapter = newModelAdapter
                    var updatedManagers = modelAdapterDictionary
                    if let anID = zoneID, let anAdapter = newModelAdapter {
                        updatedManagers[anID] = anAdapter
                    }
                    newModelAdapter?.prepareForImport()
                    modelAdapterDictionary = updatedManagers
                }
            }
            if modelAdapter != nil {
                if let anID = zoneID, let aToken = modelAdapter?.serverChangeToken() {
                    activeZoneTokens[anID] = aToken
                }
            }
        }
    }

    func filteredZoneIDs(_ zoneIDs: [Any]?, managedByManagerIn managers: [Any]?) -> [Any]? {
        var filteredZoneIDs: [AnyHashable] = []
        for zoneID: CKRecordZoneID? in zoneIDs as? [CKRecordZoneID?] ?? [CKRecordZoneID?]() {
            for modelAdapter: QSModelAdapter? in managers as? [QSModelAdapter?] ?? [QSModelAdapter?]() {
                if modelAdapter?.recordZoneID == zoneID {
                    if let anID = zoneID {
                        filteredZoneIDs.append(anID)
                    }
                    continue
                }
            }
        }
        return filteredZoneIDs
    }

    func resetActiveTokens() {
        activeZoneTokens = [AnyHashable : Any]()
    }

    func fetchZoneChanges(_ zoneIDs: [Any]?, withCompletion completion: @escaping () -> Void) {
        let completionBlock: ((_ zoneResults: [CKRecordZoneID : QSFetchZoneChangesOperationZoneResult]) -> Void)? = { zoneResults in
                self.dispatchQueue.async(execute: {
                    var pendingZones: [AnyHashable] = []
                    zoneResults.enumerateKeysAndObjects(usingBlock: { zoneID, zoneResult, stop in
                        let modelAdapter = self.modelAdapterDictionary[zoneID] as? QSModelAdapter
                        if zoneResult.error.code == .changeTokenExpired {
                            modelAdapter?.saveToken(nil)
                        } else {
                            DLog("QSCloudKitSynchronizer >> Downloaded %ld changed records >> from zone %@", UInt(zoneResult.downloadedRecords.count), zoneID)
                            DLog("QSCloudKitSynchronizer >> Downloaded %ld deleted record IDs >> from zone %@", UInt(zoneResult.deletedRecordIDs.count), zoneID)
                            if let anID = zoneID {
                                self.activeZoneTokens[zoneID] = zoneResult.self.serverChangeToken
                            }
                            modelAdapter?.saveChanges(inRecords: zoneResult.downloadedRecords)
                            modelAdapter?.deleteRecords(withIDs: zoneResult.deletedRecordIDs)
                            if zoneResult.moreComing {
                                pendingZones.append(zoneID)
                            }
                        }
                    })
                    if pendingZones.count != 0 {
                        self.fetchZoneChanges(pendingZones, withCompletion: completion)
                    } else {
                        callBlockIfNotNil(completion)
                    }
                })
            }
        let operation = QSFetchZoneChangesOperation(database: database, zoneIDs: zoneIDs, zoneChangeTokens: activeZoneTokens, modelVersion: compatibilityVersion, deviceIdentifier: deviceIdentifier, desiredKeys: nil, completion: completionBlock)
        run(operation)
    }

// MARK: - 2) Merge changes
    func synchronizationMergeChanges(withCompletion completion: @escaping (_ error: Error?) -> Void) {
        if cancelSync {
            try? self.finishSynchronization()
        } else {
            var modelAdapters: Set<AnyHashable> = []
            for zoneID: CKRecordZoneID? in activeZoneTokens.keys {
                if let anID = zoneID {
                    modelAdapters.insert(modelAdapterDictionary[anID])
                }
            }
            mergeChanges(modelAdapters) { error in
                callBlockIfNotNil(completion, error)
            }
        }
    }

    func mergeChanges(_ modelAdapters: Set<AnyHashable>?, completion: @escaping (_ error: Error?) -> Void) {
        let modelAdapter = modelAdapters?.first as? QSModelAdapter
        if modelAdapter == nil {
            callBlockIfNotNil(completion, nil)
        } else {
            weak var weakSelf: QSCloudKitSynchronizer? = self
            modelAdapter?.persistImportedChanges(withCompletion: { error in
                var pendingModelAdapters = modelAdapters
                pendingModelAdapters?.remove(modelAdapter)
                if error == nil {
                    if let anID = modelAdapter?.recordZoneID {
                        modelAdapter?.saveToken(self.activeZoneTokens[anID])
                    }
                }
                if error != nil {
                    callBlockIfNotNil(completion, error)
                } else {
                    weakSelf?.mergeChanges(pendingModelAdapters, completion: completion)
                }
            })
        }
    }

// MARK: - 3) Upload changes
    func synchronizationUploadChanges() {
        if cancelSync {
            try? self.finishSynchronization()
        } else {
            DispatchQueue.main.async(execute: {
                NotificationCenter.default.post(name: NSNotification.Name(QSCloudKitSynchronizerWillUploadChangesNotification), object: self)
            })
            uploadChanges(withCompletion: { error in
                if error != nil {
                    try? self.finishSynchronization()
                } else {
                    self.synchronizationUpdateServerTokens()
                }
            })
        }
    }

    func uploadChanges(withCompletion completion: @escaping (_ error: Error?) -> Void) {
        if cancelSync {
            try? self.finishSynchronization()
        } else {
            uploadEntities(forModelAdapterSet: Set<AnyHashable>(modelAdapters())) { error in
                if error != nil {
                    callBlockIfNotNil(completion, error)
                } else {
                    self.uploadDeletions(withCompletion: completion)
                }
            }
        }
    }

    func uploadDeletions(withCompletion completion: @escaping (_ error: Error?) -> Void) {
        if cancelSync {
            try? self.finishSynchronization()
        } else {
            removeDeletedEntities(fromModelAdapters: Set<AnyHashable>(modelAdapters())) { error in
                callBlockIfNotNil(completion, error)
            }
        }
    }

    func uploadEntities(forModelAdapterSet modelAdapters: Set<AnyHashable>?, completion: @escaping (_ error: Error?) -> Void) {
        if modelAdapters?.count == 0 {
            callBlockIfNotNil(completion, nil)
        } else {
            weak var weakSelf: QSCloudKitSynchronizer? = self
            let modelAdapter = modelAdapters?.first as? QSModelAdapter
            setupRecordZoneIfNeeded(modelAdapter) { error in
                if error != nil {
                    callBlockIfNotNil(completion, error)
                } else {
                    self.uploadEntities(for: modelAdapter, withCompletion: { error in
                        if error != nil {
                            callBlockIfNotNil(completion, error)
                        } else {
                            var pendingModelAdapters = modelAdapters
                            pendingModelAdapters?.remove(modelAdapter)
                            weakSelf?.uploadEntities(forModelAdapterSet: pendingModelAdapters, completion: completion)
                        }
                    })
                }
            }
        }
    }

    func uploadEntities(for modelAdapter: QSModelAdapter?, withCompletion completion: @escaping (_ error: Error?) -> Void) {
        let records = modelAdapter?.recordsToUpload(withLimit: batchSize)
        let recordCount: Int? = records?.count
        let requestedBatchSize: Int = batchSize
        if recordCount == 0 {
            callBlockIfNotNil(completion, nil)
        } else {
            weak var weakSelf: QSCloudKitSynchronizer? = self
            //Add metadata: device UUID and model version
            addMetadata(toRecords: records)
                //Now perform the operation
            let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: records as? [CKRecord], recordIDsToDelete: nil)
            var recordsToSave: [AnyHashable] = []
            modifyRecordsOperation.perRecordCompletionBlock = { record, error in
                self.dispatchQueue.async(execute: {
                    if (error as NSError?)?.code == CKError.Code.serverRecordChanged.rawValue {
                            //Update local data with server
                        let record = (error as NSError?)?.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord
                        if record != nil {
                            if let aRecord = record {
                                recordsToSave.append(aRecord)
                            }
                        }
                    }
                })
            }
            modifyRecordsOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                self.dispatchQueue.async(execute: {
                    modelAdapter?.saveChanges(inRecords: recordsToSave)
                    modelAdapter?.didUploadRecords(savedRecords)
                    DLog("QSCloudKitSynchronizer >> Uploaded %ld records", UInt(savedRecords?.count ?? 0))
                    if try? self.isLimitExceededError() != nil {
                        self.batchSize = self.batchSize / 2
                    } else if self.batchSize < QSDefaultBatchSize {
                        self.batchSize += 1
                    }
                    if (recordCount ?? 0) >= requestedBatchSize {
                        weakSelf?.uploadEntities(for: modelAdapter, withCompletion: completion)
                    } else {
                        callBlockIfNotNil(completion, operationError)
                    }
                })
            }
            currentOperation = modifyRecordsOperation
            database.add(modifyRecordsOperation)
        }
    }

    func removeDeletedEntities(fromModelAdapters modelAdapters: Set<AnyHashable>?, completion: @escaping (_ error: Error?) -> Void) {
        if modelAdapters?.count == 0 {
            callBlockIfNotNil(completion, nil)
        } else {
            weak var weakSelf: QSCloudKitSynchronizer? = self
            let modelAdapter = modelAdapters?.first as? QSModelAdapter
            removeDeletedEntities(from: modelAdapter) { error in
                if error != nil {
                    callBlockIfNotNil(completion, error)
                } else {
                    var pendingModelAdapters = modelAdapters
                    pendingModelAdapters?.remove(modelAdapter)
                    weakSelf?.removeDeletedEntities(fromModelAdapters: pendingModelAdapters, completion: completion)
                }
            }
        }
    }

    func removeDeletedEntities(from modelAdapter: QSModelAdapter?, completion: @escaping (_ error: Error?) -> Void) {
        let recordIDs = modelAdapter?.recordIDsMarkedForDeletion(withLimit: batchSize)
        let recordCount: Int? = recordIDs?.count
        if recordCount == 0 {
            callBlockIfNotNil(completion, nil)
        } else {
                //Now perform the operation
            let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs as? [CKRecordID])
            modifyRecordsOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                self.dispatchQueue.async(execute: {
                    DLog("QSCloudKitSynchronizer >> Deleted %ld records", UInt(deletedRecordIDs?.count ?? 0))
                    if (operationError as NSError?)?.code == CKError.Code.limitExceeded.rawValue {
                        self.batchSize = self.batchSize / 2
                    } else if self.batchSize < QSDefaultBatchSize {
                        self.batchSize += 1
                    }
                    modelAdapter?.didDeleteRecordIDs(deletedRecordIDs)
                    callBlockIfNotNil(completion, operationError)
                })
            }
            currentOperation = modifyRecordsOperation
            database.add(modifyRecordsOperation)
        }
    }

// MARK: - 4) Update tokens
    func synchronizationUpdateServerTokens() {
        let completionBlock: ((_ _Nullable: CKServerChangeToken?, _ _Nonnull: [CKRecordZoneID]?, _ _Nonnull: [CKRecordZoneID]?) -> Void)? = { databaseToken, changedZoneIDs, deletedZoneIDs in
                self.notifyProvider(forDeletedZoneIDs: deletedZoneIDs)
                if changedZoneIDs.count != 0 {
                    self.updateServerToken(forRecordZones: changedZoneIDs, withCompletion: { needToFetchFullChanges in
                        if needToFetchFullChanges {
                            //There were changes before we finished, repeat process again
                            self.performSynchronization()
                        } else {
                            self.serverChangeToken = databaseToken
                            try? self.finishSynchronization()
                        }
                    })
                } else {
                    try? self.finishSynchronization()
                }
            }
        let operation = QSFetchDatabaseChangesOperation(database: database, databaseToken: serverChangeToken, completion: completionBlock)
        run(operation)
    }

    func updateServerToken(forRecordZones zoneIDs: [CKRecordZoneID]?, withCompletion completion: @escaping (_ needToFetchFullChanges: Bool) -> Void) {
        let completionBlock: ((_ _Nonnull: [CKRecordZoneID : QSFetchZoneChangesOperationZoneResult]?) -> Void)? = { zoneResults in
                self.dispatchQueue.async(execute: {
                    var pendingZones: [AnyHashable] = []
                    var needsToRefetch = false
                    zoneResults.enumerateKeysAndObjects(usingBlock: { zoneID, result, stop in
                        let modelAdapter = self.modelAdapterDictionary[zoneID] as? QSModelAdapter
                        if result.downloadedRecords.count || result.deletedRecordIDs.count {
                            needsToRefetch = true
                        } else {
                            modelAdapter?.saveToken(result.self.serverChangeToken)
                        }
                        if result.moreComing {
                            pendingZones.append(zoneID)
                        }
                    })
                    if pendingZones.count != 0 && !needsToRefetch {
                        self.updateServerToken(forRecordZones: pendingZones as? [CKRecordZoneID], withCompletion: completion)
                    } else {
                        callBlockIfNotNil(completion, needsToRefetch)
                    }
                })
            }
        let operation = QSFetchZoneChangesOperation(database: database, zoneIDs: zoneIDs, zoneChangeTokens: activeZoneTokens, modelVersion: compatibilityVersion, deviceIdentifier: deviceIdentifier, desiredKeys: ["recordID", QSCloudKitDeviceUUIDKey], completion: completionBlock)
        run(operation)
    }

// MARK: - 5) Finish
    func finishSynchronization() throws {
        syncing = false
        cancelSync = false
        resetActiveTokens()
        for modelAdapter: QSModelAdapter? in modelAdapters() ?? [QSModelAdapter?]() {
            try? modelAdapter?.didFinishImport()
        }
        DispatchQueue.main.async(execute: {
            if error != nil {
                if let anError = error {
                    NotificationCenter.default.post(name: NSNotification.Name(QSCloudKitSynchronizerDidFailToSynchronizeNotification), object: self, userInfo: [QSCloudKitSynchronizerErrorKey: anError])
                }
            } else {
                NotificationCenter.default.post(name: NSNotification.Name(QSCloudKitSynchronizerDidSynchronizeNotification), object: self)
            }
            callBlockIfNotNil(self.completion, error)
            self.completion = nil
        })
        DLog("QSCloudKitSynchronizer >> Finishing synchronization")
    }

    func cancelError() -> Error? {
        return NSError(domain: QSCloudKitSynchronizerErrorDomain, code: QSCloudKitSynchronizerErrorCode.qsCloudKitSynchronizerErrorCancelled.rawValue, userInfo: [QSCloudKitSynchronizerErrorKey: "Synchronization was canceled"])
    }

    func run(_ operation: QSCloudKitSynchronizerOperation?) {
        operation.errorHandler = { operation, error in
            try? self.finishSynchronization()
        }
        currentOperation = operation
        operationQueue?.addOperation(operation)
    }

    func notifyProvider(forDeletedZoneIDs zoneIDs: [CKRecordZoneID]?) {
        for zoneID: CKRecordZoneID? in zoneIDs ?? [CKRecordZoneID?]() {
            if let anID = zoneID {
                adapterProvider?.cloudKitSynchronizer(self, zoneWasDeletedWith: anID)
            }
        }
    }

    func isLimitExceededError() throws {
        if (error as NSError).code == CKError.Code.partialFailure.rawValue {
            let errorsByItemID = (error as NSError).userInfo[CKPartialErrorsByItemIDKey]
            for error: Error in errorsByItemID.allValues as? [Error] ?? [Error]() {
                if (error as NSError).code == CKError.Code.limitExceeded.rawValue {
                    return true
                }
            }
        }
        return (error as NSError).code == CKError.Code.limitExceeded.rawValue
    }

// MARK: - RecordZone setup
    func needsZoneSetup(_ modelAdapter: QSModelAdapter?) -> Bool {
        return modelAdapter?.serverChangeToken == nil
    }

    func setupRecordZoneIfNeeded(_ modelAdapter: QSModelAdapter?, completion: @escaping (_ error: Error?) -> Void) {
        if needsZoneSetup(modelAdapter) {
            setupRecordZone(modelAdapter?.recordZoneID, withCompletion: { error in
                callBlockIfNotNil(completion, error)
            })
        } else {
            completion(nil)
        }
    }

    func setupRecordZone(_ zoneID: CKRecordZoneID?, withCompletion completionBlock: @escaping (_ error: Error?) -> Void) {
        if let anID = zoneID {
            database.fetch(withRecordZoneID: anID, completionHandler: { zone, error in
                if zone != nil {
                    callBlockIfNotNil(completionBlock, error)
                } else if (error as NSError?)?.code == CKError.Code.zoneNotFound.rawValue || (error as NSError?)?.code == CKError.Code.userDeletedZone.rawValue {
                    var newZone: CKRecordZone? = nil
                    if let anID = zoneID {
                        newZone = CKRecordZone(zoneID: anID)
                    }
                    if let aZone = newZone {
                        self.database.save(aZone, completionHandler: { zone, error in
                            if error == nil && zone != nil {
                                DLog("QSCloudKitSynchronizer >> Created custom record zone: %@", zone)
                            }
                            callBlockIfNotNil(completionBlock, error)
                        })
                    }
                } else {
                    callBlockIfNotNil(completionBlock, error)
                }
            })
        }
    }
}