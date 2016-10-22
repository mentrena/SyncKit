//
//  QSChangeManager.h
//  Pods
//
//  Created by Manuel Entrena on 13/07/2016.
//
//

#import <Foundation/Foundation.h>
@class CKRecord;
@class CKRecordID;

/**
 *  Posted whenever a change manager detects there are new local changes to sync.
 */
static NSString * const QSChangeManagerHasChangesNotification = @"QSChangeManagerHasChangesNotification";

/**
 *  An object conforming to `QSChangeManager` will track the local model, provide changes to upload to CloudKit and import downloaded changes.
 */
@protocol QSChangeManager <NSObject>

/**
 *  @return Whether the model has any changes
 */
- (BOOL)hasChanges;

/**
 *  Tells the change manager that an import operation will begin
 */
- (void)prepareForImport;

/**
 *  Apply changes in the provided record to the local model object and save the record itself.
 *
 *  @param record `CKRecord` that was obtained from CloudKit.
 */
- (void)saveChangesInRecord:(CKRecord *)record;

/**
 *  Delete the local model object corresponding to the given record ID.
 *
 *  @param recordID Identifier of record that was deleted on CloudKit.
 */
- (void)deleteRecordWithID:(CKRecordID *)recordID;

/**
 *  Tells the change manager to persist all downloaded changes in the current import operation.
 *
 *  @param completion Block to be called after changes have been persisted.
 */
- (void)persistImportedChangesWithCompletion:(void(^)(NSError *error))completion;

/**
 *  Provides an array of up to `limit` records with changes that need to be uploaded to CloudKit.
 *
 *  @param limit Maximum number of records that should be provided.
 *
 *  @return Array of `CKRecord`.
 */
- (NSArray *)recordsToUploadWithLimit:(NSInteger)limit;

/**
 *  Tells the change manager that these records were uploaded successfully.
 *
 *  @param savedRecords Records that were saved.
 */
- (void)didUploadRecords:(NSArray *)savedRecords;

/**
 *  Provides an array of record IDs to be deleted on CloudKit, for model objects that were deleted locally.
 *
 *  @return Array of `CKRecordID`.
 */
- (NSArray *)recordIDsMarkedForDeletionWithLimit:(NSInteger)limit;

/**
 *  Tells the change manager that these record identifiers were deleted successfully.
 *
 *  @param deletedRecordIDs Record IDs that were deleted on CloudKit.
 */
- (void)didDeleteRecordIDs:(NSArray *)deletedRecordIDs;

/**
 *  Asks the change manager whether it has a local object for the given record identifier.
 *
 *  @param recordID Record identifier.
 *
 *  @return Whether there is a corresponding object for this identifier.
 */
- (BOOL)hasRecordID:(CKRecordID *)recordID;

/**
 *  Tells the change manager that the current import operation finished.
 *
 *  @param error Optional error, if any error happened.
 */
- (void)didFinishImportWithError:(NSError *)error;

/**
 *  Deletes all tracking information and detaches from local model.
 */
- (void)deleteChangeTracking;

@end
