//
//  ModelAdapter.swift
//  Pods-CoreDataExample
//
//  Created by Manuel Entrena on 25/04/2019.
//

import Foundation
import CloudKit

/// The merge policy to resolve change conflicts. Default value is `server`
@objc public enum MergePolicy: Int {
    
    /// Downloaded changes have preference.
    case server
    /// Local changes have preference.
    case client
    /// Delegate can resolve changes manually.
    case custom
}

public extension Notification.Name {
    
    /// Sent by the model adapter when it detects changes to some objects. The notification is sent only once, if there were no changes before and new changes were detected.
    static let ModelAdapterHasChangesNotification = Notification.Name("QSModelAdapterHasChangesNotification")
}

@objc public extension NSNotification {
    
    /// /// Sent by the model adapter when it detects changes to some objects. The notification is sent only once, if there were no changes before and new changes were detected.
    static let ModelAdapterHasChangesNotification: NSString = "QSModelAdapterHasChangesNotification"
}

/// An object conforming to `ModelAdapter` will track the local model, provide changes to upload to CloudKit and import downloaded changes.
@objc public protocol ModelAdapter: class {
    
    /// Whether the model has any changes
    var hasChanges: Bool { get }
    
    /// Tells the model adapter that an import operation will begin
    func prepareToImport()
    
    /// Apply changes in the provided record to the local model objects and save the records.
    /// - Parameter records: Array of `CKRecord` that were obtained from CloudKit.
    func saveChanges(in records: [CKRecord])
    
    /// Delete the local model objects corresponding to the given record IDs.
    /// - Parameter recordIDs: Array of identifiers of records that were deleted on CloudKit.
    func deleteRecords(with recordIDs: [CKRecord.ID])
    
    /// Tells the model adapter to persist all downloaded changes in the current import operation.
    /// - Parameter completion: Block to be called after changes have been persisted.
    func persistImportedChanges(completion: @escaping (Error?)->())
    
    /// Provides an array of up to `limit` records with changes that need to be uploaded to CloudKit.
    /// - Parameter limit: Maximum number of records that should be provided.
    /// - Returns: Array of `CKRecord`.
    func recordsToUpload(limit: Int) -> [CKRecord]
    
    /// Tells the model adapter that these records were uploaded successfully to CloudKit.
    /// - Parameter savedRecords: Records that were saved.
    func didUpload(savedRecords: [CKRecord])
    
    /// Provides an array of record IDs to be deleted on CloudKit, for model objects that were deleted locally.
    /// - Parameter limit: Maximum number of records that should be provided.
    /// - Returns: Array of `CKRecordID`.
    func recordIDsMarkedForDeletion(limit: Int) -> [CKRecord.ID]
    
    /// Tells the model adapter that these record identifiers were deleted successfully from CloudKit.
    /// - Parameter recordIDs: Record IDs that were deleted on CloudKit.
    func didDelete(recordIDs: [CKRecord.ID])
    
    /// Asks the model adapter whether it has a local object for the given record identifier.
    /// - Parameter recordID: Record identifier.
    /// - Returns: Whether there is a corresponding object for this identifier.
    func hasRecordID(_ recordID: CKRecord.ID) -> Bool
    
    /// Tells the model adapter that the current import operation finished.
    /// - Parameter error: Optional error, if any error happened.
    func didFinishImport(with error: Error?)
    
    /// Record zone ID managed by this adapter
    var recordZoneID: CKRecordZone.ID { get }
    
    /// Latest `CKServerChangeToken` stored by this adapter, or `nil` if one does not exist.
    var serverChangeToken: CKServerChangeToken? { get }
    
    /// Save given token for future use by this adapter.
    /// - Parameter token: `CKServerChangeToken`
    func saveToken(_ token: CKServerChangeToken?)
    
    /**
     *  Deletes all tracking information and detaches from local model.
     *  This adapter should not be used after calling this method, create a new adapter if you wish to synchronize
     *  the same model again.
     */
    func deleteChangeTracking()
    
    
    /// Merge policy in case of conflicts. Default is `server`.
    var mergePolicy: MergePolicy {get set}
    
    /// Returns corresponding `CKRecord` for the given model object.
    /// - Parameter object: Model object.
    func record(for object: AnyObject) -> CKRecord?

    /// Returns CKShare for the given model object, if one exists.
    /// - Parameter object: Model object.
    @available(iOS 10.0, OSX 10.12, *) func share(for object: AnyObject) -> CKShare?
    
    /// Store CKShare for given model object.
    /// - Parameters:
    ///   - share: `CKShare` object to save.
    ///   - object: Model object.
    @available(iOS 10.0, OSX 10.12, *) func save(share: CKShare, for object: AnyObject)
    
    /// Delete existing `CKShare` for given model object.
    /// - Parameter object: Model object.
    @available(iOS 10.0, OSX 10.12, *) func deleteShare(for object: AnyObject)
    
    /// - Returns: CKShare for the adapter's record zone, if one exists.
    @available(iOS 15.0, OSX 12, watchOS 8.0, *) func shareForRecordZone() -> CKShare?
    
    /// Store CKShare for the record zone.
    /// - Parameters:
    ///   - share: `CKShare` object to save.
    @available(iOS 15.0, OSX 12, watchOS 8.0, *) func saveShareForRecordZone(share: CKShare)
    
    /// Delete existing `CKShare` for adapter's record zone.
    @available(iOS 15.0, OSX 12, watchOS 8.0, *) func deleteShareForRecordZone()
    
    /// Returns a list of records for the given object and any parent records, recursively.
    /// - Parameter object: Model object.
    /// - Returns: Array of `CKRecord`
    func recordsToUpdateParentRelationshipsForRoot(_ object: AnyObject) -> [CKRecord]
}
