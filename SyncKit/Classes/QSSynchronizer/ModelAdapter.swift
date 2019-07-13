//
//  ModelAdapter.swift
//  Pods-CoreDataExample
//
//  Created by Manuel Entrena on 25/04/2019.
//

import Foundation
import CloudKit

/**
 *  The merge policy to resolve change conflicts. Default value is `QSModelAdapterMergePolicyServer`
 */
@objc public enum MergePolicy: Int {
    
    // Downloaded changes have preference.
    case server
    // Local changes have preference.
    case client
    // Delegate can resolve changes manually.
    case custom
}

public extension Notification.Name {
    static let ModelAdapterHasChangesNotification = Notification.Name("QSModelAdapterHasChangesNotification")
}

@objc public extension NSNotification {
    static let ModelAdapterHasChangesNotification: NSString = "QSModelAdapterHasChangesNotification"
}

/**
 *  An object conforming to `QSModelAdapter` will track the local model, provide changes to upload to CloudKit and import downloaded changes.
 */
@objc public protocol ModelAdapter: class {
    
    /**
     *  @return Whether the model has any changes
     */
    var hasChanges: Bool { get }
    
    /**
     *  Tells the change manager that an import operation will begin
     */
    func prepareToImport()
    
    /**
     *  Apply changes in the provided record to the local model objects and save the records.
     *
     *  @param records Array of `CKRecord` that were obtained from CloudKit.
     */
    func saveChanges(in records: [CKRecord])
    
    /**
     *  Delete the local model objects corresponding to the given record IDs.
     *
     *  @param recordIDs Array of identifiers of records that were deleted on CloudKit.
     */
    func deleteRecords(with recordIDs: [CKRecord.ID])
    
    /**
     *  Tells the change manager to persist all downloaded changes in the current import operation.
     *
     *  @param completion Block to be called after changes have been persisted.
     */
    func persistImportedChanges(completion: @escaping (Error?)->())
    
    /**
     *  Provides an array of up to `limit` records with changes that need to be uploaded to CloudKit.
     *
     *  @param limit Maximum number of records that should be provided.
     *
     *  @return Array of `CKRecord`.
     */
    func recordsToUpload(limit: Int) -> [CKRecord]
    
    /**
     *  Tells the change manager that these records were uploaded successfully.
     *
     *  @param savedRecords Records that were saved.
     */
    func didUpload(savedRecords: [CKRecord])
    
    /**
     *  Provides an array of record IDs to be deleted on CloudKit, for model objects that were deleted locally.
     *
     *  @return Array of `CKRecordID`.
     */
    func recordIDsMarkedForDeletion(limit: Int) -> [CKRecord.ID]
    
    /**
     *  Tells the change manager that these record identifiers were deleted successfully.
     *
     *  @param deletedRecordIDs Record IDs that were deleted on CloudKit.
     */
    func didDelete(recordIDs: [CKRecord.ID])
    
    /**
     *  Asks the change manager whether it has a local object for the given record identifier.
     *
     *  @param recordID Record identifier.
     *
     *  @return Whether there is a corresponding object for this identifier.
     */
    func hasRecordID(_ recordID: CKRecord.ID) -> Bool
    
    /**
     *  Tells the change manager that the current import operation finished.
     *
     *  @param error Optional error, if any error happened.
     */
    func didFinishImport(with error: Error?)
    
    /**
     *  Returns record zone ID managed by this adapter
     *
     *  @return CKRecordID
     */
    var recordZoneID: CKRecordZone.ID { get }
    
    /**
     *  Returns latest CKServerChangeToken stored by this adapter, or NULL if one does not exist.
     *
     *  @return CKServerChangeToken.
     */
    var serverChangeToken: CKServerChangeToken? { get }
    
    /**
     *  Save given token for future use by this adapter.
     *
     *  @param token CKServerChangeToken
     */
    func saveToken(_ token: CKServerChangeToken?)
    
    /**
     *  Deletes all tracking information and detaches from local model.
     */
    func deleteChangeTracking()
    
    var mergePolicy: MergePolicy {get set}
    
    /**
     *  Returns corresponding CKRecord for the given model object.
     *
     *  @param object Model object.
     */
    func record(for object: AnyObject) -> CKRecord?
    
    /**
     *  Returns CKShare for the given model object, if one exists.
     *
     *  @param object Model object.
     */
    @available(iOS 10.0, OSX 10.12, *)
    func share(for object: AnyObject) -> CKShare?
    
    /**
     *  Store CKShare for given model object.
     *
     *  @param share CKShare object to save.
     *  @param object Model object.
     */
    @available(iOS 10.0, OSX 10.12, *)
    func save(share: CKShare, for object: AnyObject)
    
    /**
     *  Delete existing CKShare for given model object.
     *
     *  @param object Model object.
     */
    @available(iOS 10.0, OSX 10.12, *)
    func deleteShare(for object: AnyObject)
    
    
    func recordsToUpdateParentRelationshipsForRoot(_ object: AnyObject) -> [CKRecord]
}
