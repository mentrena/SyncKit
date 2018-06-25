//
//  QSModelAdapter.h
//  Pods
//
//  Created by Manuel Entrena on 13/07/2016.
//
//

#import <Foundation/Foundation.h>
@class CKRecord;
@class CKRecordID;
@class CKRecordZoneID;
@class CKShare;
@class CKServerChangeToken;

/**
 *  The merge policy to resolve change conflicts. Default value is `QSModelAdapterMergePolicyServer`
 */
typedef NS_ENUM(NSInteger, QSModelAdapterMergePolicy) {
    /**
     *  Downloaded changes have preference.
     */
    QSModelAdapterMergePolicyServer,
    /**
     *  Local changes have preference.
     */
    QSModelAdapterMergePolicyClient,
    /**
     *  Delegate can resolve changes manually.
     */
    QSModelAdapterMergePolicyCustom
};

/**
 *  Posted whenever a change manager detects there are new local changes to sync.
 */
static NSString * _Nonnull const QSModelAdapterHasChangesNotification = @"QSModelAdapterHasChangesNotification";

/**
 *  An object conforming to `QSModelAdapter` will track the local model, provide changes to upload to CloudKit and import downloaded changes.
 */
@protocol QSModelAdapter <NSObject>

/**
 *  @return Whether the model has any changes
 */
- (BOOL)hasChanges;

/**
 *  Tells the change manager that an import operation will begin
 */
- (void)prepareForImport;

/**
 *  Apply changes in the provided record to the local model objects and save the records.
 *
 *  @param records Array of `CKRecord` that were obtained from CloudKit.
 */
- (void)saveChangesInRecords:(nonnull NSArray<CKRecord *> *)records;

/**
 *  Delete the local model objects corresponding to the given record IDs.
 *
 *  @param recordIDs Array of identifiers of records that were deleted on CloudKit.
 */
- (void)deleteRecordsWithIDs:(nonnull NSArray<CKRecordID *> *)recordIDs;

/**
 *  Tells the change manager to persist all downloaded changes in the current import operation.
 *
 *  @param completion Block to be called after changes have been persisted.
 */
- (void)persistImportedChangesWithCompletion:(void(^_Nonnull)(NSError * _Nullable error))completion;

/**
 *  Provides an array of up to `limit` records with changes that need to be uploaded to CloudKit.
 *
 *  @param limit Maximum number of records that should be provided.
 *
 *  @return Array of `CKRecord`.
 */
- (nonnull NSArray<CKRecord *> *)recordsToUploadWithLimit:(NSInteger)limit;

/**
 *  Tells the change manager that these records were uploaded successfully.
 *
 *  @param savedRecords Records that were saved.
 */
- (void)didUploadRecords:(nonnull NSArray<CKRecord *> *)savedRecords;

/**
 *  Provides an array of record IDs to be deleted on CloudKit, for model objects that were deleted locally.
 *
 *  @return Array of `CKRecordID`.
 */
- (nonnull NSArray<CKRecordID *> *)recordIDsMarkedForDeletionWithLimit:(NSInteger)limit;

/**
 *  Tells the change manager that these record identifiers were deleted successfully.
 *
 *  @param deletedRecordIDs Record IDs that were deleted on CloudKit.
 */
- (void)didDeleteRecordIDs:(nonnull NSArray<CKRecordID *> *)deletedRecordIDs;

/**
 *  Asks the change manager whether it has a local object for the given record identifier.
 *
 *  @param recordID Record identifier.
 *
 *  @return Whether there is a corresponding object for this identifier.
 */
- (BOOL)hasRecordID:(CKRecordID *_Nonnull)recordID;

/**
 *  Tells the change manager that the current import operation finished.
 *
 *  @param error Optional error, if any error happened.
 */
- (void)didFinishImportWithError:(NSError *_Nullable)error;

/**
 *  Returns corresponding CKRecord for the given model object.
 *
 *  @param object Model object.
 */
- (nullable CKRecord *)recordForObject:(id)object;
/**
 *  Returns CKShare for the given model object, if one exists.
 *
 *  @param object Model object.
 */
- (nullable CKShare *)shareForObject:(id)object NS_AVAILABLE(10.12, 10.0);
/**
 *  Store CKShare for given model object.
 *
 *  @param share CKShare object to save.
 *  @param object Model object.
 */
- (void)saveShare:(nonnull CKShare *)share forObject:(id)object NS_AVAILABLE(10.12, 10.0);
/**
 *  Delete existing CKShare for given model object.
 *
 *  @param object Model object.
 */
- (void)deleteShareForObject:(id)object NS_AVAILABLE(10.12, 10.0);

/**
 *  Returns record zone ID managed by this adapter
 *
 *  @return CKRecordID
 */
- (nonnull CKRecordZoneID *)recordZoneID;
/**
 *  Returns latest CKServerChangeToken stored by this adapter, or NULL if one does not exist.
 *
 *  @return CKServerChangeToken.
 */
- (nullable CKServerChangeToken *)serverChangeToken;
/**
 *  Save given token for future use by this adapter.
 *
 *  @param token CKServerChangeToken
 */
- (void)saveToken:(nullable CKServerChangeToken *)token;

/**
 *  Deletes all tracking information and detaches from local model.
 */
- (void)deleteChangeTracking;

/**
 *  Merge policy to be used in case of conflicts. Default value is `QSModelAdapterMergePolicyServer`
 */
@property (nonatomic, assign) QSModelAdapterMergePolicy mergePolicy;

@optional

- (NSArray<CKRecord *> *)recordsToUpdateParentRelationshipsForRoot:(id)object;

@end
