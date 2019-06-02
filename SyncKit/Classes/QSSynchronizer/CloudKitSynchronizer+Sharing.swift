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
     */
    @objc func saveShare(_ share: CKShare, for object: AnyObject) {
        guard let modelAdapter = modelAdapter(for: object) else {
            return
        }
        modelAdapter.save(share: share, for: object)
    }
    
    /**
     Deletes any `CKShare` locally stored  for the given model object.
     - Parameters:
     - object  The model object.
     */
    @objc func deleteShare(for object: AnyObject) {
        guard let modelAdapter = modelAdapter(for: object) else {
            return
        }
        modelAdapter.deleteShare(for: object)
    }
    
    /**
     Creates and uploads a new `CKShare` for the given model object.
     - Parameters:
     - object The model object to share.
     - publicPermission  The permissions to be used for the new share.
     - participants: The participants to add to this share.
     - completion: Closure that gets called with an optional error when the operation is completed.
     
     */
    @objc func share(object: AnyObject, publicPermission: CKShare.Participant.Permission, participants: [CKShare.Participant], completion: ((CKShare?, Error?) -> ())?) {
        
        guard let modelAdapter = modelAdapter(for: object),
            let record = modelAdapter.record(for: object) else {
                return
        }
        let share = CKShare(rootRecord: record)
        share.publicPermission = publicPermission
        for participant in participants {
            share.addParticipant(participant)
        }
        
        addMetadata(to: [record, share])
        
        let operation = CKModifyRecordsOperation(recordsToSave: [record, share], recordIDsToDelete: nil)
        
        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
            
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
                                completion?(uploadedShare, error)
                            }
                        }
                    })
                    
                } else {
                    
                    DispatchQueue.main.async {
                        completion?(uploadedShare, operationError)
                    }
                }
            }
        }
        
        database.add(operation)
    }
    
    /**
     Removes the existing `CKShare` for an object and deletes it from CloudKit.
     - Parameters:
     - object  The model object.
     - completion Closure that gets called on completion.
     */
    @objc func removeShare(for object: AnyObject, completion: ((Error?) -> ())?) {
        
        guard let modelAdapter = modelAdapter(for: object),
            let share = modelAdapter.share(for: object),
            let record = modelAdapter.record(for: object) else {
                completion?(nil)
                return
        }
        
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
                                completion?(error)
                            }
                        }
                    })
                    
                } else {
                    
                    DispatchQueue.main.async {
                        completion?(operationError)
                    }
                }
            }
        }
        
        database.add(operation)
    }
    
    /**
     Reuploads to CloudKit all `CKRecord`s for the given root model object and all of its children (see `QSParentKey`). This function can be used to ensure all objects in the hierarchy have their `parent` property correctly set, before sharing, if their records had been created before sharing was supported.
     - Parameters:
     - root The root model object.
     - completion Closure that gets called on completion.
     */
    @objc func reuploadRecordsForChildrenOf(root: AnyObject, completion: ((Error?) -> ())?) {
        
        guard let modelAdapter = modelAdapter(for: root) else {
            completion?(nil)
            return
        }
        
        let records = modelAdapter.recordsToUpdateParentRelationshipsForRoot(root)
        
        guard records.count > 0 else {
                completion?(nil)
                return
        }
        
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
            
            if operationError == nil,
                let savedRecords = savedRecords {
                modelAdapter.didUpload(savedRecords: savedRecords)
            }
            
            completion?(operationError)
        }
        
        database.add(operation)
    }
}
