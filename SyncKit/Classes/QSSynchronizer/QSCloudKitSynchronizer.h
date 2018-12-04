//
//  QSCloudKitHelper.h
//  Quikstudy
//
//  Created by Manuel Entrena on 26/05/2016.
//  Copyright © 2016 Manuel Entrena. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QSModelAdapter.h"
#import "QSKeyValueStore.h"
#import <CloudKit/CloudKit.h>

@class CKRecordZoneID;

FOUNDATION_EXPORT NSString * _Nonnull const QSCloudKitSynchronizerErrorDomain;

typedef NS_ENUM(NSInteger, QSCloudKitSynchronizerErrorCode)
{
    QSCloudKitSynchronizerErrorAlreadySyncing,
    QSCloudKitSynchronizerErrorHigherModelVersionFound,
    QSCloudKitSynchronizerErrorCancelled
};

typedef NS_ENUM(NSInteger, QSCloudKitSynchronizeMode)
{
    QSCloudKitSynchronizeModeSync,
    QSCloudKitSynchronizeModeDownload
};

@class QSCloudKitSynchronizer;

/**
    A `QSCloudKitSynchronizerAdapterProvider` gets requested for new model adapters when a `QSCloudKitSynchronizer` encounters a new `CKRecordZone` that does not already correspond to an existing model adapter.
 */

@protocol QSCloudKitSynchronizerAdapterProvider

@optional

/**
 *  The `QSCloudKitSynchronizer` requests a new model adapter for the given record zone.
 *
 *  @param synchronizer `QSCloudKitSynchronizer` asking for the adapter.
 *  @param recordZoneID `CKRecordZoneID` that the model adapter will be used for.
 *
 *  @return QSModelAdapter correctly configured to sync changes in the given record zone.
 */
- (id<QSModelAdapter> _Nullable)cloudKitSynchronizer:(QSCloudKitSynchronizer *_Nonnull)synchronizer modelAdapterForRecordZoneID:(CKRecordZoneID *_Nonnull)recordZoneID;

/**
 *  The `QSCloudKitSynchronizer` informs the provider that a record zone was deleted so it can clean up any associated data.
 *
 *  @param synchronizer `QSCloudKitSynchronizer` that found the deleted record zone.
 *  @param recordZoneID `CKRecordZoneID` of the record zone that was deleted.
 */
- (void)cloudKitSynchronizer:(QSCloudKitSynchronizer *_Nonnull)synchronizer zoneWasDeletedWithZoneID:(CKRecordZoneID *_Nonnull)recordZoneID;

@end

/**
    A `QSCloudKitSynchronizer` object takes care of making all the required calls to CloudKit to keep your model synchronized, using the provided
    `QSModelAdapter` to interact with it.
    `QSCloudKitSynchronizer` will post notifications at different steps of the synchronization process.
 */

@interface QSCloudKitSynchronizer : NSObject

/**
 *  A unique identifier used for this synchronizer. It is used for some state-preservation.
 */

@property (nonatomic, readonly) NSString * _Nonnull identifier;

/**
 *  The identifier of the iCloud container used for synchronization. (read-only)
 */
@property (nonatomic, readonly) NSString * _Nonnull containerIdentifier;

/**
 *  Indicates whether the synchronizer is currently performing a synchronization. (read-only)
 */
@property (atomic, readonly, getter=isSyncing) BOOL syncing;
/**
 *  Number of items that will be included in an upload to CloudKit.
 *  Could be changed by the synchronizer to adjust to CloudKit limits.
 */
@property (nonatomic, assign) NSInteger batchSize;

/**
 *  If the version is set (!= 0) and the synchronizer downloads records with a higher version then
 *  synchronization will end with the appropriate error.
 */
@property (nonatomic, assign) NSInteger compatibilityVersion;

/**
 *  Sync mode: full sync or download only
 */
@property (nonatomic, assign) QSCloudKitSynchronizeMode syncMode;

/**
 *  CloudKit database.
 */
@property (nonatomic, readonly, nonnull) CKDatabase *database;

/**
 *  Adapter provider, to dynamically provide a new model adapter when a new record zone is found in the assigned cloudKit database.
 */
@property (nonatomic, readonly, nullable) id<QSCloudKitSynchronizerAdapterProvider> adapterProvider;

/**
 *  A key-value store for some state-preservation.
 */
@property (nonatomic, readonly, nonnull) id<QSKeyValueStore> keyValueStore;

/**
 *  Array of keys added to `CKRecord` objects by the `QSCloudKitSynchronizer`. These keys should be ignored by model adapters when applying changes from `CKRecord` to model objects.
 */
+ (NSArray<NSString *> * _Nonnull)synchronizerMetadataKeys;

/**
 *  All the model adapters currently being synced by this `QSCloudKitSynchronizer`
 */
- (NSArray<id<QSModelAdapter> > * _Nonnull)modelAdapters;

/**
 *  Adds a new model adapter for syncing.
 */
- (void)addModelAdapter:(nonnull id<QSModelAdapter>)modelAdapter;

/**
 *  Removed a model adapter from this synchronizer.
 */
- (void)removeModelAdapter:(nonnull id<QSModelAdapter>)modelAdapter;



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
- (nonnull instancetype)initWithIdentifier:(nonnull NSString *)identifier containerIdentifier:(nonnull NSString *)containerIdentifier database:(nonnull CKDatabase *)database adapterProvider:(nullable id<QSCloudKitSynchronizerAdapterProvider>)adapterProvider;

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
- (nonnull instancetype)initWithIdentifier:(nonnull NSString *)identifier containerIdentifier:(nonnull NSString *)containerIdentifier database:(nonnull CKDatabase *)database adapterProvider:(nullable id<QSCloudKitSynchronizerAdapterProvider>)adapterProvider keyValueStore:(nonnull id<QSKeyValueStore>)keyValueStore;

/**
 *  Performs synchronization with CloudKit.
 *
 *  @param completion A block that will be called after synchronization ends. The block will receive an `NSError` if an error happened during synchronization.
 */
- (void)synchronizeWithCompletion:(void(^_Nullable)(NSError * _Nullable error))completion;

/**
 *  Cancel an ongoing synchronization.
 */
- (void)cancelSynchronization;

/**
 *  Erase all local metadata to stop synchronizing.
 */
- (void)eraseLocalMetadata;

/**
 *  This will delete the `CKRecordZone` that is used by the model adapter, erasing all content in that record zone.
 */
- (void)deleteRecordZoneForModelAdapter:(nonnull id<QSModelAdapter>)modelAdapter withCompletion:(void(^_Nullable)(NSError * _Nullable error))completion;

@end

/**
 *  Posted whenever a synchronizer begins a synchronization.
    The notification object is the synchronizer.
 */
FOUNDATION_EXPORT NSString * _Nonnull const QSCloudKitSynchronizerWillSynchronizeNotification;

/**
 *  Posted before a synchronizer asks CloudKit for any changes to download.
    The notification object is the synchronizer.
 */
FOUNDATION_EXPORT NSString * _Nonnull const QSCloudKitSynchronizerWillFetchChangesNotification;
/**
 *  Posted before a synchronizer sends local changes to CloudKit.
    The notification object is the synchronizer.
 */
FOUNDATION_EXPORT NSString * _Nonnull const QSCloudKitSynchronizerWillUploadChangesNotification;
/**
 *  Posted whenever a synchronizer finishes a synchronization.
    The notification object is the synchronizer.
 */
FOUNDATION_EXPORT NSString * _Nonnull const QSCloudKitSynchronizerDidSynchronizeNotification;
/**
 *  Posted whenever a synchronizer finishes a synchronization with an error.
    The notification object is the synchronizer.
 
    The <i>userInfo</i> dictionary contains the error under the <i>QSCloudKitSynchronizerErrorKey</i> key
 */
FOUNDATION_EXPORT NSString * _Nonnull const QSCloudKitSynchronizerDidFailToSynchronizeNotification;

/**
 *  Key inside any notification user info dictionary that will provide the underlying CloudKit error.
 */
FOUNDATION_EXPORT NSString * _Nonnull const QSCloudKitSynchronizerErrorKey;
