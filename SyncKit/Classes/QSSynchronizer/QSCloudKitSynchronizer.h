//
//  QSCloudKitHelper.h
//  Quikstudy
//
//  Created by Manuel Entrena on 26/05/2016.
//  Copyright © 2016 Manuel Entrena. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QSChangeManager.h"

@class CKRecordZoneID;

FOUNDATION_EXPORT NSString * const QSCloudKitDeviceUUIDKey;
FOUNDATION_EXPORT NSString * const QSCloudKitSynchronizerErrorDomain;

typedef NS_ENUM(NSInteger, QSCloudKitSynchronizerErrorCode)
{
    QSCloudKitSynchronizerErrorAlreadySyncing
};

/**
    A `QSCloudKitSynchronizer` object takes care of making all the required calls to CloudKit to keep your model synchronized, using the provided
    `QSChangeManager` to interact with it.
    `QSCloudKitSynchronizer` will post notifications at different steps of the synchronization process.
 */

@interface QSCloudKitSynchronizer : NSObject

/**
 *  The identifier of the iCloud container used for synchronization. (read-only)
 */
@property (nonatomic, readonly) NSString *containerIdentifier;
/**
 *  The change manager used to talk to the local model. (read-only)
 */
@property (nonatomic, strong, readonly) id<QSChangeManager> changeManager;
/**
 *  Indicates whether the synchronizer is currently performing a synchronization. (read-only)
 */
@property (atomic, readonly, getter=isSyncing) BOOL syncing;
/**
 *  Maximum number of items that will be included in an upload to CloudKit. (read-only)
 */
@property (nonatomic, readonly) NSInteger batchSize;


/**
 *  Initializes a newly allocated synchronizer.
 *
 *  @param containerIdentifier Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param zoneID              Identifier of the`CKRecordZone` that will contain all data.
 *  @param changeManager       Object conforming to `QSChangeManager`, to interact with local model.
 *
 *  @return Initialized synchronizer or `nil` if no iCloud container can be found with the provided identifier.
 */
- (instancetype)initWithContainerIdentifier:(NSString *)containerIdentifier recordZoneID:(CKRecordZoneID *)zoneID changeManager:(id<QSChangeManager>)changeManager;

/**
 *  Performs synchronization with CloudKit.
 *
 *  @param completion A block that will be called after synchronization ends. The block will receive an `NSError` if an error happened during synchronization.
 */
- (void)synchronizeWithCompletion:(void(^)(NSError *error))completion;

/**
 *  Cancel an ongoing synchronization.
 */
- (void)cancelSynchronization;

/**
 *  Creates a new subscription with CloudKit so the application can receive notifications when new changes happen. The application is responsible for registering for remote notifications and initiating synchronization when a notification is received. @see `CKSubscription`
 *
 *  @param completion Block that will be called after subscription is created, with an optional error.
 */
- (void)subscribeForUpdateNotificationsWithCompletion:(void(^)(NSError *error))completion;

/**
 *  Delete existing subscription to stop receiving notifications.
 *
 *  @param completion Block that will be called after subscription is deleted, with an optional error.
 */
- (void)deleteSubscriptionWithCompletion:(void(^)(NSError *error))completion;


/**
 *  Returns YES if there is an existing `CKSubscription` for changes in CloudKit.
 */
- (BOOL)isSubscribedForUpdateNotifications;

/**
 *  Erase all local change tracking to stop synchronizing.
 */
- (void)eraseLocal;

/**
 *  Erase all data currently in CloudKit. This will delete the `CKRecordZone` that was used by the synchronizer.
 */
- (void)eraseRemoteAndLocalDataWithCompletion:(void(^)(NSError *error))completion;

@end

/**
 *  Posted whenever a synchronizer begins a synchronization.
    The notification object is the synchronizer.
 */
FOUNDATION_EXPORT NSString * const QSCloudKitSynchronizerWillSynchronizeNotification;

/**
 *  Posted before a synchronizer asks CloudKit for any changes to download.
    The notification object is the synchronizer.
 */
FOUNDATION_EXPORT NSString * const QSCloudKitSynchronizerWillFetchChangesNotification;
/**
 *  Posted before a synchronizer sends local changes to CloudKit.
    The notification object is the synchronizer.
 */
FOUNDATION_EXPORT NSString * const QSCloudKitSynchronizerWillUploadChangesNotification;
/**
 *  Posted whenever a synchronizer finishes a synchronization.
    The notification object is the synchronizer.
 */
FOUNDATION_EXPORT NSString * const QSCloudKitSynchronizerDidSynchronizeNotification;
/**
 *  Posted whenever a synchronizer finishes a synchronization with an error.
    The notification object is the synchronizer.
 
    The <i>userInfo</i> dictionary contains the error under the <i>QSCloudKitSynchronizerErrorKey</i> key
 */
FOUNDATION_EXPORT NSString * const QSCloudKitSynchronizerDidFailToSynchronizeNotification;

/**
 *  Key inside any notification user info dictionary that will provide the underlying CloudKit error.
 */
FOUNDATION_EXPORT NSString * const QSCloudKitSynchronizerErrorKey;
