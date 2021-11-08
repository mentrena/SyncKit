//
//  CloudKitSynchronizer+Sharing.swift
//  Pods
//
//  Created by Manuel Entrena on 07/04/2019.
//

import Foundation
import CloudKit

@objc public extension CloudKitSynchronizer {
    
    fileprivate func modelAdapter(for object: AnyObject) -> ModelAdapter? {
        for modelAdapter in modelAdapters {
            if modelAdapter.record(for: object) != nil {
                return modelAdapter
            }
        }
        return nil
    }
    
    fileprivate func modelAdapter(forRecordZoneID zoneID: CKRecordZone.ID) -> ModelAdapter? {
        return modelAdapters.first { $0.recordZoneID == zoneID }
    }
    
    /**
     Returns the locally stored `CKShare` for a given model object.
     - Parameter object  The model object.
     - Returns: `CKShare` stored for the given object.
     */
    @objc func share(for object: AnyObject) -> CKShare? {
        guard let modelAdapter = modelAdapter(for: object) else {
            return nil
        }
        return modelAdapter.share(for: object)
    }
    
    /**
     Saves the given `CKShare` locally for the given model object.
     - Parameters:
        - share The `CKShare`.
        - object  The model object.
     
        This method should be called by your `UICloudSharingControllerDelegate`, when `cloudSharingControllerDidSaveShare` is called.
     */
    @objc func cloudSharingControllerDidSaveShare(_ share: CKShare, for object: AnyObject) {
        guard let modelAdapter = modelAdapter(for: object) else {
            return
        }
        modelAdapter.save(share: share, for: object)
    }
    
    /**
     Deletes any `CKShare` locally stored  for the given model object.
     - Parameters:
        - object  The model object.
     This method should be called by your `UICloudSharingControllerDelegate`, when `cloudSharingControllerDidStopSharing` is called.
     */
    @objc func cloudSharingControllerDidStopSharing(for object: AnyObject) {
        guard let modelAdapter = modelAdapter(for: object) else {
            return
        }
        
        modelAdapter.deleteShare(for: object)
        
        /**
         There is a bug on CloudKit. The record that was shared will be changed as a result of its share being deleted.
         However, this change is not returned by CloudKit on the next CKFetchZoneChangesOperation, so our local record
         becomes out of sync. To avoid that, we will fetch it here and update our local copy.
         */
        
        guard let record = modelAdapter.record(for: object) else {
            return
        }

        database.fetch(withRecordID: record.recordID) { (updated, error) in
            if let updated = updated {
                modelAdapter.prepareToImport()
                modelAdapter.saveChanges(in: [updated])
                modelAdapter.persistImportedChanges { (error) in
                    modelAdapter.didFinishImport(with: error)
                }
            }
        }
    }
    
    /**
     Returns a  `CKShare` for the given model object. If one does not exist, it creates and uploads a new
     - Parameters:
        - object The model object to share.
        - publicPermission  The permissions to be used for the new share.
        - participants: The participants to add to this share.
        - completion: Closure that gets called with an optional error when the operation is completed.
     
     */
    @objc func share(object: AnyObject, publicPermission: CKShare.Participant.Permission, participants: [CKShare.Participant], completion: ((CKShare?, Error?) -> ())?) {
        
        guard !syncing else {
            completion?(nil, CloudKitSynchronizer.SyncError.alreadySyncing)
            return
        }
        
        guard let modelAdapter = modelAdapter(for: object),
            let record = modelAdapter.record(for: object) else {
                completion?(nil, CloudKitSynchronizer.SyncError.recordNotFound)
                return
        }
        
        if let share = modelAdapter.share(for: object) {
            completion?(share, nil)
            return
        }
        
        syncing = true
        
        let share = CKShare(rootRecord: record)
        share.publicPermission = publicPermission
        for participant in participants {
            share.addParticipant(participant)
        }
        
        addMetadata(to: [record, share])
        
        let operation = ModifyRecordsOperation(database: database, records: [record, share], recordIDsToDelete: nil) { (savedRecords, deleted, conflicted, operationError) in
            self.dispatchQueue.async {
                
                let uploadedShare = savedRecords?.first { $0 is CKShare} as? CKShare
                
                if let savedRecords = savedRecords,
                   operationError == nil,
                   let share = uploadedShare {
                    
                    modelAdapter.prepareToImport()
                    let records = savedRecords.filter { $0 != share }
                    modelAdapter.didUpload(savedRecords: records)
                    modelAdapter.persistImportedChanges(completion: { (error) in
                        
                        self.dispatchQueue.async {
                            
                            if error == nil {
                                modelAdapter.save(share: share, for: object)
                            }
                            modelAdapter.didFinishImport(with: error)
                            
                            DispatchQueue.main.async {
                                self.syncing = false
                                completion?(uploadedShare, error)
                            }
                        }
                    })
                    
                } else if let error = operationError {
                    if self.isServerRecordChangedError(error as NSError),
                       !conflicted.isEmpty {
                        modelAdapter.prepareToImport()
                        modelAdapter.saveChanges(in: conflicted)
                        modelAdapter.persistImportedChanges { (error) in
                            modelAdapter.didFinishImport(with: error)
                            DispatchQueue.main.async {
                                self.syncing = false
                                self.share(object: object, publicPermission: publicPermission, participants: participants, completion: completion)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.syncing = false
                            completion?(uploadedShare, operationError)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.syncing = false
                        completion?(nil, operationError)
                    }
                }
            }
        }
        runOperation(operation)
    }
    
    /**
     Removes the existing `CKShare` for an object and deletes it from CloudKit.
     - Parameters:
        - object  The model object.
        - completion Closure that gets called on completion.
     */
    @objc func removeShare(for object: AnyObject, completion: ((Error?) -> ())?) {
        
        guard !syncing else {
            completion?(CloudKitSynchronizer.SyncError.alreadySyncing)
            return
        }
        
        guard let modelAdapter = modelAdapter(for: object),
            let share = modelAdapter.share(for: object),
            let record = modelAdapter.record(for: object) else {
                completion?(nil)
                return
        }
        
        syncing = true
        
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: [share.recordID])
        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
            
            self.dispatchQueue.async {
                
                if let savedRecords = savedRecords,
                    operationError == nil {
                    
                    modelAdapter.prepareToImport()
                    modelAdapter.didUpload(savedRecords: savedRecords)
                    modelAdapter.persistImportedChanges(completion: { (error) in
                        
                        self.dispatchQueue.async {
                            if error == nil {
                                modelAdapter.deleteShare(for: object)
                            }
                            modelAdapter.didFinishImport(with: error)
                            
                            DispatchQueue.main.async {
                                self.syncing = false
                                completion?(error)
                            }
                        }
                    })
                    
                } else {
                    
                    DispatchQueue.main.async {
                        self.syncing = false
                        completion?(operationError)
                    }
                }
            }
        }
        
        database.add(operation)
    }
    
    /**
     Returns the locally stored `CKShare` for a given record zone.
     - Parameter zoneID  The record zone ID.
     - Returns: `CKShare` stored for the given object.
     */
    @available(iOS 15.0, OSX 12, watchOS 8.0, *)
    @objc func share(forRecordZoneID zoneID: CKRecordZone.ID) -> CKShare? {
        guard let modelAdapter = modelAdapter(forRecordZoneID: zoneID) else {
            return nil
        }
        return modelAdapter.shareForRecordZone()
    }
    
    /**
     Saves the given `CKShare` locally for the given record zone ID.
     - Parameters:
        - share The `CKShare`.
        - zoneID  The record zone ID..
     
        This method should be called by your `UICloudSharingControllerDelegate`, when `cloudSharingControllerDidSaveShare` is called.
     */
    @available(iOS 15.0, OSX 12, watchOS 8.0, *)
    @objc func cloudSharingControllerDidSaveShare(_ share: CKShare, forRecordZoneID zoneID: CKRecordZone.ID) {
        guard let modelAdapter = modelAdapter(forRecordZoneID: zoneID) else {
            return
        }
        modelAdapter.saveShareForRecordZone(share: share)
    }
    
    /**
     Deletes any `CKShare` locally stored  for the given record zone ID
     - Parameters:
        - zoneID  The record zone ID.
     This method should be called by your `UICloudSharingControllerDelegate`, when `cloudSharingControllerDidStopSharing` is called.
     */
    @available(iOS 15.0, OSX 12, watchOS 8.0, *)
    @objc func cloudSharingControllerDidStopSharing(forRecordZoneID zoneID: CKRecordZone.ID) {
        guard let modelAdapter = modelAdapter(forRecordZoneID: zoneID) else {
            return
        }
        
        modelAdapter.deleteShareForRecordZone()
    }
    
    /**
     Returns a  `CKShare` for the given record zone. If one does not exist, it creates and uploads a new
     - Parameters:
        - recordZoneID The ID of the record zone to share.
        - publicPermission  The permissions to be used for the new share.
        - participants: The participants to add to this share.
        - completion: Closure that gets called with an optional error when the operation is completed.
     
     */
    @available(iOS 15.0, OSX 12, watchOS 8.0, *)
    @objc func share(recordZoneID: CKRecordZone.ID, publicPermission: CKShare.ParticipantPermission, participants: [CKShare.Participant], completion: ((CKShare?, Error?) -> ())?) {
        guard !syncing else {
            completion?(nil, CloudKitSynchronizer.SyncError.alreadySyncing)
            return
        }

        guard let modelAdapter = modelAdapter(forRecordZoneID: recordZoneID) else {
                completion?(nil, CloudKitSynchronizer.SyncError.recordNotFound)
                return
        }

        if let share = modelAdapter.shareForRecordZone() {
            completion?(share, nil)
            return
        }

        syncing = true

        let share = CKShare(recordZoneID: recordZoneID)
        share.publicPermission = publicPermission
        for participant in participants {
            share.addParticipant(participant)
        }

        addMetadata(to: [share])

        let operation = ModifyRecordsOperation(database: database, records: [share], recordIDsToDelete: nil) { (savedRecords, deleted, conflicted, operationError) in
            self.dispatchQueue.async {
                
                if operationError == nil,
                   let share = savedRecords?.first(where: { $0 is CKShare}) as? CKShare {
                    
                    modelAdapter.saveShareForRecordZone(share: share)
                    DispatchQueue.main.async {
                        self.syncing = false
                        completion?(share, nil)
                    }
                    
                } else if let error = operationError,
                          self.isServerRecordChangedError(error as NSError),
                          !conflicted.isEmpty,
                          let share = conflicted.first as? CKShare {
                    modelAdapter.saveShareForRecordZone(share: share)
                    DispatchQueue.main.async {
                        self.syncing = false
                        completion?(share, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.syncing = false
                        completion?(nil, operationError)
                    }
                }
            }
        }
        runOperation(operation)
    }
    
    /**
     Removes the existing `CKShare` for the record zone and deletes it from CloudKit.
     - Parameters:
        - recordZoneID  The ID of the record zone to unshare.
        - completion Closure that gets called on completion.
     */
    @available(iOS 15.0, OSX 12, watchOS 8.0, *)
    @objc func removeShare(recordZoneID: CKRecordZone.ID, completion: ((Error?) -> ())?) {
        guard !syncing else {
            completion?(CloudKitSynchronizer.SyncError.alreadySyncing)
            return
        }
        
        guard let modelAdapter = modelAdapter(forRecordZoneID: recordZoneID),
            let share = modelAdapter.shareForRecordZone() else {
                completion?(nil)
                return
        }
        
        syncing = true
        
        let operation = CKModifyRecordsOperation(recordsToSave: [], recordIDsToDelete: [share.recordID])
        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
            
            self.dispatchQueue.async {
                
                if let deletedRecordID = deletedRecordIDs?.first,
                   deletedRecordID == share.recordID,
                   operationError == nil {
                    
                    modelAdapter.deleteShareForRecordZone()
                    
                    DispatchQueue.main.async {
                        self.syncing = false
                        completion?(nil)
                    }
                    
                } else {
                    
                    DispatchQueue.main.async {
                        self.syncing = false
                        completion?(operationError)
                    }
                }
            }
        }
        
        database.add(operation)
    }
    
    /**
     Reuploads to CloudKit all `CKRecord`s for the given root model object and all of its children (see `ParentKey`). This function can be used to ensure all objects in the hierarchy have their `parent` property correctly set, before sharing, if their records had been created before sharing was supported.
     - Parameters:
        - root The root model object.
        - completion Closure that gets called on completion.
     */
    @objc func reuploadRecordsForChildrenOf(root: AnyObject, completion: @escaping ((Error?) -> ())) {
        
        guard !syncing else {
            completion(CloudKitSynchronizer.SyncError.alreadySyncing)
            return
        }
        
        guard let modelAdapter = modelAdapter(for: root) else {
            completion(nil)
            return
        }
        
        let records = modelAdapter.recordsToUpdateParentRelationshipsForRoot(root)
        
        guard records.count > 0 else {
                completion(nil)
                return
        }
        
        syncing = true
        
        let chunks = stride(from: 0, to: records.count, by: batchSize).map {
            Array(records[$0..<Swift.min($0 + batchSize, records.count)])
        }
        
        let finalBlock: ((Error?) -> ()) = { error in
            DispatchQueue.main.async {
                self.syncing = false
                completion(error)
            }
        }
        
        sequential(objects: chunks,
                   closure: { (records, uploadCompletion) in
                    let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
                    operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                        
                        if operationError == nil,
                            let savedRecords = savedRecords {
                            modelAdapter.didUpload(savedRecords: savedRecords)
                        }
                        
                        if let error = operationError {
                            if self.isLimitExceededError(error as NSError) {
                                self.batchSize = self.batchSize / 2
                            }
                        }
                        
                        uploadCompletion(operationError)
                    }
                    self.currentOperation = operation
                    self.database.add(operation)
        },
                   final: finalBlock)
    }
}
