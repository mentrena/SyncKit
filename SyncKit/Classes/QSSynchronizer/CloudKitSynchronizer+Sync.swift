//
//  CloudKitSynchronizer+Sync.swift
//  Pods
//
//  Created by Manuel Entrena on 17/04/2019.
//

import Foundation
import CloudKit

extension CloudKitSynchronizer {
    
    func performSynchronization() {
        dispatchQueue.async {
            self.postNotification(.SynchronizerWillSynchronize)
            self.delegate?.synchronizerWillStartSyncing(self)
            self.serverChangeToken = self.storedDatabaseToken
            self.uploadRetries = 0
            self.didNotifyUpload = Set<CKRecordZone.ID>()
            
            self.modelAdapters.forEach {
                $0.prepareToImport()
            }
            
            self.fetchChanges()
        }
    }
    
    func finishSynchronization(error: Error?) {
        resetActiveTokens()
        
        self.uploadRetries = 0
        
        for adapter in modelAdapters {
            adapter.didFinishImport(with: error)
        }
        
        DispatchQueue.main.async {
            self.syncing = false
            self.cancelSync = false
            self.completion?(error)
            self.completion = nil
            
            if let error = error {
                self.postNotification(.SynchronizerDidFailToSynchronize, userInfo: [CloudKitSynchronizer.errorKey: error])
                self.delegate?.synchronizerDidfailToSync(self, error: error)
            } else {
                self.postNotification(.SynchronizerDidSynchronize)
                self.delegate?.synchronizerDidSync(self)
            }
            
            debugPrint("QSCloudKitSynchronizer >> Finishing synchronization")
        }
    }
}

// MARK: - Utilities

extension CloudKitSynchronizer {
    
    func postNotification(_ notification: Notification.Name, object: Any? = self, userInfo: [AnyHashable: Any]? = nil) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: notification, object: object, userInfo: userInfo)
        }
    }
    
    func runOperation(_ operation: CloudKitSynchronizerOperation) {
        operation.errorHandler = { [weak self] operation, error in
            self?.finishSynchronization(error: error)
        }
        currentOperation = operation
        operationQueue.addOperation(operation)
    }
    
    func notifyProviderForDeletedZoneIDs(_ zoneIDs: [CKRecordZone.ID]) {
        zoneIDs.forEach {
            self.adapterProvider.cloudKitSynchronizer(self, zoneWasDeletedWithZoneID: $0)
            self.delegate?.synchronizer(self, zoneIDWasDeleted: $0)
        }
    }
    
    func loadTokens(for zoneIDs: [CKRecordZone.ID], loadAdapters: Bool) -> [CKRecordZone.ID] {
        
        var filteredZoneIDs = [CKRecordZone.ID]()
        activeZoneTokens = [CKRecordZone.ID: CKServerChangeToken]()
        
        for zoneID in zoneIDs {
            var modelAdapter = modelAdapterDictionary[zoneID]
            if modelAdapter == nil && loadAdapters {
                if let newModelAdapter = adapterProvider.cloudKitSynchronizer(self, modelAdapterForRecordZoneID: zoneID) {
                    modelAdapter = newModelAdapter
                    modelAdapterDictionary[zoneID] = newModelAdapter
                    delegate?.synchronizer(self, didAddAdapter: newModelAdapter, forRecordZoneID: zoneID)
                    newModelAdapter.prepareToImport()
                }
            }
            
            if let adapter = modelAdapter {
                filteredZoneIDs.append(zoneID)
                activeZoneTokens[zoneID] = adapter.serverChangeToken
            }
        }
        
        return filteredZoneIDs
    }
    
    func resetActiveTokens() {
        activeZoneTokens = [CKRecordZone.ID: CKServerChangeToken]()
    }
    
    func shouldRetryUpload(for error: NSError) -> Bool {
        if isServerRecordChangedError(error) || isLimitExceededError(error) {
            return uploadRetries < 2
        } else {
            return false
        }
    }
    
    func isServerRecordChangedError(_ error: NSError) -> Bool {
        
        if error.code == CKError.partialFailure.rawValue,
            let errorsByItemID = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: NSError],
            errorsByItemID.values.contains(where: { (error) -> Bool in
                return error.code == CKError.serverRecordChanged.rawValue
            }) {
            
            return true
        }
        
        return error.code == CKError.serverRecordChanged.rawValue
    }
    
    func isZoneNotFoundOrDeletedError(_ error: Error?) -> Bool {
        if let error = error {
            let nserror = error as NSError
            return nserror.code == CKError.zoneNotFound.rawValue || nserror.code == CKError.userDeletedZone.rawValue
        } else {
            return false
        }
    }
    
    func isLimitExceededError(_ error: NSError) -> Bool {
        
        if error.code == CKError.partialFailure.rawValue,
            let errorsByItemID = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: NSError],
            errorsByItemID.values.contains(where: { (error) -> Bool in
                return error.code == CKError.limitExceeded.rawValue
            }) {
            
            return true
        }
        
        return error.code == CKError.limitExceeded.rawValue
    }
    
    func sequential<T>(objects: [T], closure: @escaping (T, @escaping (Error?)->())->(), final: @escaping  (Error?)->()) {
        
        guard let first = objects.first else {
            final(nil)
            return
        }
        
        closure(first) { error in
            guard error == nil else {
                final(error)
                return
            }
            
            var remaining = objects
            remaining.removeFirst()
            self.sequential(objects: remaining, closure: closure, final: final)
        }
    }
    
    func needsZoneSetup(adapter: ModelAdapter) -> Bool {
        return adapter.serverChangeToken == nil
    }
}

//MARK: - Fetch changes

extension CloudKitSynchronizer {
    
    func fetchChanges() {
        guard cancelSync == false else {
            finishSynchronization(error: SyncError.cancelled)
            return
        }
        
        postNotification(.SynchronizerWillFetchChanges)
        delegate?.synchronizerWillCheckForChanges(self)
        fetchDatabaseChanges() { token, error in
            guard error == nil else {
                self.finishSynchronization(error: error)
                return
            }
            
            self.serverChangeToken = token
            self.storedDatabaseToken = token
            if self.syncMode == .sync {
                self.uploadChanges()
            } else {
                self.finishSynchronization(error: nil)
            }
        }
    }
    
    func fetchDatabaseChanges(completion: @escaping (CKServerChangeToken?, Error?) -> ()) {
        
        let operation = FetchDatabaseChangesOperation(database: database, databaseToken: serverChangeToken) { (token, changedZoneIDs, deletedZoneIDs) in
            self.dispatchQueue.async {
                self.notifyProviderForDeletedZoneIDs(deletedZoneIDs)
                
                let zoneIDsToFetch = self.loadTokens(for: changedZoneIDs, loadAdapters: true)
                
                guard zoneIDsToFetch.count > 0 else {
                    self.resetActiveTokens()
                    completion(token, nil)
                    return
                }
                
                zoneIDsToFetch.forEach {
                    self.delegate?.synchronizerWillFetchChanges(self, in: $0)
                }
                
                self.fetchZoneChanges(zoneIDsToFetch) { error in
                    guard error == nil else {
                        self.finishSynchronization(error: error)
                        return
                    }
                    
                    self.mergeChanges() { error in
                        completion(token, error)
                    }
                }
            }
        }
        
        runOperation(operation)
    }
    
    func fetchZoneChanges(_ zoneIDs: [CKRecordZone.ID], completion: @escaping (Error?)->()) {
        
        let operation = FetchZoneChangesOperation(database: database, zoneIDs: zoneIDs, zoneChangeTokens: activeZoneTokens, modelVersion: compatibilityVersion, ignoreDeviceIdentifier: deviceIdentifier, desiredKeys: nil) { (zoneResults) in
            
            self.dispatchQueue.async {
                var pendingZones = [CKRecordZone.ID]()
                var error: Error? = nil
                
                for (zoneID, result) in zoneResults {
                    let adapter = self.modelAdapterDictionary[zoneID]
                    if let resultError = result.error {
                        if (self.isZoneNotFoundOrDeletedError(error))
                        {
                            self.notifyProviderForDeletedZoneIDs([zoneID])
                        }
                        else
                        {
                            error = resultError
                            break
                        }
                    } else {
                        debugPrint("QSCloudKitSynchronizer >> Downloaded \(result.downloadedRecords.count) changed records >> from zone \(zoneID.description)")
                        debugPrint("QSCloudKitSynchronizer >> Downloaded \(result.deletedRecordIDs.count) deleted record IDs >> from zone \(zoneID.description)")
                        self.activeZoneTokens[zoneID] = result.serverChangeToken
                        adapter?.saveChanges(in: result.downloadedRecords)
                        adapter?.deleteRecords(with: result.deletedRecordIDs)
                        if result.moreComing {
                            pendingZones.append(zoneID)
                        } else {
                            self.delegate?.synchronizerDidFetchChanges(self, in: zoneID)
                        }
                    }
                }
                
                if pendingZones.count > 0 && error == nil {
                    self.fetchZoneChanges(pendingZones, completion: completion)
                } else {
                    completion(error)
                }
            }
        }
        
        runOperation(operation)
    }
    
    func mergeChanges(completion: @escaping (Error?)->()) {
        guard cancelSync == false else {
            finishSynchronization(error: SyncError.cancelled)
            return
        }
        
        var adapterSet = [ModelAdapter]()
        activeZoneTokens.keys.forEach {
            if let adapter = self.modelAdapterDictionary[$0] {
                adapterSet.append(adapter)
            }
        }

        sequential(objects: adapterSet, closure: mergeChangesIntoAdapter, final: completion)
    }
    
    func mergeChangesIntoAdapter(_ adapter: ModelAdapter, completion: @escaping (Error?)->()) {

        adapter.persistImportedChanges { error in
            self.dispatchQueue.async {
                guard error == nil else {
                    completion(error)
                    return
                }
                
                adapter.saveToken(self.activeZoneTokens[adapter.recordZoneID])
                completion(nil)
            }
        }
    }
}

// MARK: - Upload changes

extension CloudKitSynchronizer {
    
    func uploadChanges() {
        guard cancelSync == false else {
            finishSynchronization(error: SyncError.cancelled)
            return
        }
        
        postNotification(.SynchronizerWillUploadChanges)
        
        uploadChanges() { (error) in
            if let error = error {
                if self.shouldRetryUpload(for: error as NSError) {
                    self.uploadRetries += 1
                    self.fetchChanges()
                } else {
                    self.finishSynchronization(error: error)
                }
            } else {
                self.increaseBatchSize()
                self.updateTokens()
            }
        }
    }
    
    func uploadChanges(completion: @escaping (Error?)->()) {
        
        sequential(objects: modelAdapters, closure: setupZoneAndUploadRecords) { (error) in
            guard error == nil else { completion(error); return }
            
            self.sequential(objects: self.modelAdapters, closure: self.uploadDeletions, final: completion)
        }
    }
    
    func setupZoneAndUploadRecords(adapter: ModelAdapter, completion: @escaping (Error?)->()) {
        setupRecordZoneIfNeeded(adapter: adapter) { (error) in
            
            guard error == nil else {
                completion(error)
                return
            }
            
            self.uploadRecords(adapter: adapter, completion: { (error) in
                completion(error)
            })
        }
    }
    
    func setupRecordZoneIfNeeded(adapter: ModelAdapter, completion: @escaping (Error?)->()) {
        guard needsZoneSetup(adapter: adapter) else {
            completion(nil)
            return
        }
        
        setupRecordZoneID(adapter.recordZoneID, completion: completion)
    }
    
    func setupRecordZoneID(_ zoneID: CKRecordZone.ID, completion: @escaping (Error?)->()) {
        database.fetch(withRecordZoneID: zoneID) { (zone, error) in
            if self.isZoneNotFoundOrDeletedError(error) {
                let newZone = CKRecordZone(zoneID: zoneID)
                self.database.save(zone: newZone, completionHandler: { (zone, error) in
                    if error == nil && zone != nil {
                        debugPrint("QSCloudKitSynchronizer >> Created custom record zone: \(newZone.description)")
                    }
                    completion(error)
                })
            } else {
                completion(error)
            }
        }
    }
    
    func uploadRecords(adapter: ModelAdapter,  completion: @escaping (Error?)->()) {
        let records = adapter.recordsToUpload(limit: batchSize)
        let recordCount = records.count
        let requestedBatchSize = batchSize
        guard recordCount > 0 else { completion(nil); return }
        
        if !didNotifyUpload.contains(adapter.recordZoneID) {
            didNotifyUpload.insert(adapter.recordZoneID)
            delegate?.synchronizerWillUploadChanges(self, to: adapter.recordZoneID)
        }
        
        
        //Add metadata: device UUID and model version
        addMetadata(to: records)
        
        let modifyRecordsOperation = ModifyRecordsOperation(database: database,
                                               records: records,
                                               recordIDsToDelete: nil)
        { (savedRecords, deleted, conflicted, operationError) in
            self.dispatchQueue.async {
                
                debugPrint("QSCloudKitSynchronizer >> Uploaded \(savedRecords?.count ?? 0) records")
                adapter.didUpload(savedRecords: savedRecords ?? [])
                
                if let error = operationError {
                    if self.isLimitExceededError(error as NSError) {
                        self.reduceBatchSize()
                        completion(error)
                    } else if !conflicted.isEmpty {
                        adapter.saveChanges(in: conflicted)
                        adapter.persistImportedChanges { (persistError) in
                            completion(error)
                        }
                    } else {
                        completion(error)
                    }
                } else {
                    if recordCount >= requestedBatchSize {
                        self.uploadRecords(adapter: adapter, completion: completion)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
        
        runOperation(modifyRecordsOperation)
    }
    
    func uploadDeletions(adapter: ModelAdapter, completion: @escaping (Error?)->()) {
        
        let recordIDs = adapter.recordIDsMarkedForDeletion(limit: batchSize)
        let recordCount = recordIDs.count
        let requestedBatchSize = batchSize
        
        guard recordCount > 0 else {
            completion(nil)
            return
        }
        
        let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        modifyRecordsOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
            self.dispatchQueue.async {
                
                debugPrint("QSCloudKitSynchronizer >> Deleted \(recordCount) records")
                adapter.didDelete(recordIDs: deletedRecordIDs ?? [])
                
                if let error = operationError {
                    if self.isLimitExceededError(error as NSError) {
                        self.reduceBatchSize()
                    }
                    completion(error)
                } else {
                    if recordCount >= requestedBatchSize {
                        self.uploadDeletions(adapter: adapter, completion: completion)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
        
        currentOperation = modifyRecordsOperation
        database.add(modifyRecordsOperation)
    }
    
    // MARK: - 
    
    func updateTokens() {
        let operation = FetchDatabaseChangesOperation(database: database, databaseToken: serverChangeToken) { (databaseToken, changedZoneIDs, deletedZoneIDs) in
            self.dispatchQueue.async {
                self.notifyProviderForDeletedZoneIDs(deletedZoneIDs)
                if changedZoneIDs.count > 0 {
                    let zoneIDs = self.loadTokens(for: changedZoneIDs, loadAdapters: false)
                    self.updateServerToken(for: zoneIDs, completion: { (needsToFetchChanges) in
                        if needsToFetchChanges {
                            self.performSynchronization()
                        } else {
                            self.storedDatabaseToken = databaseToken
                            self.finishSynchronization(error: nil)
                        }
                    })
                } else {
                    self.finishSynchronization(error: nil)
                }
            }
        }
        runOperation(operation)
    }
    
    func updateServerToken(for recordZoneIDs: [CKRecordZone.ID], completion: @escaping (Bool)->()) {
        
        // If we found a new record zone at this point then needsToFetchChanges=true
        var hasAllTokens = true
        for zoneID in recordZoneIDs {
            if activeZoneTokens[zoneID] == nil {
                hasAllTokens = false
            }
        }
        guard hasAllTokens else {
            completion(true)
            return
        }
        
        let operation = FetchZoneChangesOperation(database: database, zoneIDs: recordZoneIDs, zoneChangeTokens: activeZoneTokens, modelVersion: compatibilityVersion, ignoreDeviceIdentifier: deviceIdentifier, desiredKeys: ["recordID", CloudKitSynchronizer.deviceUUIDKey]) { (zoneResults) in
            self.dispatchQueue.async {
                var pendingZones = [CKRecordZone.ID]()
                var needsToRefetch = false
                
                for (zoneID, result) in zoneResults {
                    let adapter = self.modelAdapterDictionary[zoneID]
                    if result.downloadedRecords.count > 0 || result.deletedRecordIDs.count > 0 {
                        needsToRefetch = true
                    } else {
                        self.activeZoneTokens[zoneID] = result.serverChangeToken
                        adapter?.saveToken(result.serverChangeToken)
                    }
                    if result.moreComing {
                        pendingZones.append(zoneID)
                    }
                }
                
                if pendingZones.count > 0 && !needsToRefetch {
                    self.updateServerToken(for: pendingZones, completion: completion)
                } else {
                    completion(needsToRefetch)
                }
            }
        }
        runOperation(operation)
    }
    
    func reduceBatchSize() {
        self.batchSize = self.batchSize / 2
    }
    
    func increaseBatchSize() {
        if self.batchSize < CloudKitSynchronizer.defaultBatchSize {
            self.batchSize = self.batchSize + 5
        }
    }
}
