//
//  QSCloudKitHelper.m
//  Quikstudy
//
//  Created by Manuel Entrena on 26/05/2016.
//  Copyright © 2016 Manuel Entrena. All rights reserved.
//

#import "QSCloudKitSynchronizer.h"
#import "QSRecord.h"
#import <CloudKit/CloudKit.h>

#define callBlockIfNotNil(block, ...) if (block){block(__VA_ARGS__);}

NSString * const QSCloudKitSynchronizerWillSynchronizeNotification = @"QSCloudKitSynchronizerWillSynchronizeNotification";
NSString * const QSCloudKitSynchronizerWillFetchChangesNotification = @"QSCloudKitSynchronizerWillFetchChangesNotification";
NSString * const QSCloudKitSynchronizerWillUploadChangesNotification = @"QSCloudKitSynchronizerWillUploadChangesNotification";
NSString * const QSCloudKitSynchronizerDidSynchronizeNotification = @"QSCloudKitSynchronizerDidSynchronizeNotification";
NSString * const QSCloudKitSynchronizerDidFailToSynchronizeNotification = @"QSCloudKitSynchronizerDidFailToSynchronizeNotification";
NSString * const QSCloudKitSynchronizerErrorKey = @"QSCloudKitSynchronizerErrorKey";

static NSString * QSSubscriptionIdentifierKey = @"QSSubscriptionIdentifierKey";
static const NSInteger QSDefaultBatchSize = 100;
static NSString * const QSCloudKitFetchChangesServerTokenKey = @"QSCloudKitFetchChangesServerTokenKey";
static NSString * const QSCloudKitDeviceUUIDKey = @"QSCloudKitDeviceUUIDKey";

@interface QSCloudKitSynchronizer ()

@property (nonatomic, readwrite, copy) NSString *containerIdentifier;

@property (nonatomic, strong) CKServerChangeToken *serverChangeToken;

@property (nonatomic, strong) CKDatabase *database;
@property (nonatomic, strong) CKRecordZoneID *customZoneID;
@property (nonatomic, strong) CKRecordZone *customZone;
@property (atomic, readwrite, assign, getter=isSyncing) BOOL syncing;

@property (nonatomic, assign) NSInteger batchSize;

@property (nonatomic, strong, readwrite) id<QSChangeManager> changeManager;
@property (nonatomic, strong) NSString *deviceIdentifier;

@property (nonatomic, assign) BOOL cancelSync;

@property (nonatomic, copy) void(^completion)(NSError *error);

@end

@implementation QSCloudKitSynchronizer

- (instancetype)initWithContainerIdentifier:(NSString *)containerIdentifier recordZoneID:(CKRecordZoneID *)zoneID changeManager:(id<QSChangeManager>)changeManager
{
    self = [super init];
    if (self) {
        self.containerIdentifier = containerIdentifier;
        self.changeManager = changeManager;
        self.batchSize = QSDefaultBatchSize;
        CKContainer *container = [CKContainer containerWithIdentifier:self.containerIdentifier];
        
        if (!container) {
            return nil;
        }

        self.database = [container privateCloudDatabase];
        self.customZoneID = zoneID;
        [self setupCustomZoneWithCompletion:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextWillSaveNotification object:nil];
}

- (NSString *)deviceIdentifier
{
    if (!_deviceIdentifier) {
        _deviceIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:QSCloudKitDeviceUUIDKey];
        if (_deviceIdentifier) {
            NSUUID *UUID = [NSUUID UUID];
            _deviceIdentifier = [UUID UUIDString];
            [[NSUserDefaults standardUserDefaults] setObject:_deviceIdentifier forKey:QSCloudKitDeviceUUIDKey];
        }
    }
    return _deviceIdentifier;
}

- (void)setupCustomZoneWithCompletion:(void(^)(NSError *error))completionBlock
{
    if (!self.customZone) {
        [self.database fetchRecordZoneWithID:self.customZoneID completionHandler:^(CKRecordZone * _Nullable zone, NSError * _Nullable error) {
            if (zone) {
                self.customZone = zone;
                callBlockIfNotNil(completionBlock, error);
            } else {
                self.customZone = [[CKRecordZone alloc] initWithZoneID:self.customZoneID];
                [self.database saveRecordZone:self.customZone completionHandler:^(CKRecordZone * _Nullable zone, NSError * _Nullable error) {
                    callBlockIfNotNil(completionBlock, error);
                }];
            }
        }];
    } else {
        callBlockIfNotNil(completionBlock, nil);
    }
}

#pragma mark - Public

- (void)synchronizeWithCompletion:(void(^)(NSError *error))completion
{
    if (self.isSyncing) {
        return;
    }
    
    DLog(@"QSCloudKitSynchronizer >> Initiating synchronization");
    self.cancelSync = NO;
    self.syncing = YES;
    
    if (!self.customZone) {
        __weak QSCloudKitSynchronizer *weakSelf = self;
        [self setupCustomZoneWithCompletion:^(NSError *error) {
            if (error) {
                self.syncing = NO;
                callBlockIfNotNil(completion, error);
                
                [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerDidFailToSynchronizeNotification
                                                                    object:self
                                                                  userInfo:@{QSCloudKitSynchronizerErrorKey : error}];
            } else {
                [weakSelf performSynchronization];
            }
        }];
    } else {
        self.completion = completion;
        [self performSynchronization];
    }
}

- (void)cancelSynchronization
{
    self.cancelSync = YES;
}

- (void)eraseLocal
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:QSCloudKitFetchChangesServerTokenKey];
    
    [self.changeManager deleteChangeTracking];
}

- (void)eraseRemoteData
{
    __weak QSCloudKitSynchronizer *weakSelf = self;
    [self.database deleteRecordZoneWithID:self.customZoneID completionHandler:^(CKRecordZoneID * _Nullable zoneID, NSError * _Nullable error) {
        if (!error) {
            weakSelf.customZone = nil;
            DLog(@"QSCloudKitSynchronizer >> Deleted zone");
        } else {
            DLog(@"QSCloudKitSynchronizer >> Error: %@", error);
        }
    }];
}

- (void)subscribeForUpdateNotificationsWithCompletion:(void(^)(NSError *error))completion
{
    [self subscribeForChangesInRecordZoneWithCompletion:completion];
}

- (void)deleteSubscriptionWithCompletion:(void(^)(NSError *error))completion
{
    [self cancelSubscriptionForChangesInRecordZoneWithCompletion:completion];
}

#pragma mark - Sync

- (void)performSynchronization
{
    [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerWillSynchronizeNotification object:self];

    [self.changeManager prepareForImport];
    [self restoreServerChangeToken];
    [self synchronizationFetchChanges];
}

- (void)synchronizationFetchChanges
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[NSError errorWithDomain:@"QSCloudKitSynchronizer" code:0 userInfo:@{QSCloudKitSynchronizerErrorKey: @"Synchronization was canceled"}]];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerWillFetchChangesNotification object:self];
        [self fetchChangesWithCompletion:^(NSError *error) {
            if (error) {
                [self finishSynchronizationWithError:error];
            } else {
                [self synchronizationMergeChanges];
            }
        }];
    }
}

- (void)synchronizationMergeChanges
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[NSError errorWithDomain:@"QSCloudKitSynchronizer" code:0 userInfo:@{QSCloudKitSynchronizerErrorKey: @"Synchronization was canceled"}]];
    } else {
        [self.changeManager persistImportedChangesWithCompletion:^(NSError *error) {
            if (error) {
                [self finishSynchronizationWithError:error];
            } else {
                [self saveServerChangeToken:self.serverChangeToken];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self synchronizationUploadChanges];
                });
            }
        }];
    }
}

- (void)synchronizationUploadChanges
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[NSError errorWithDomain:@"QSCloudKitSynchronizer" code:0 userInfo:@{QSCloudKitSynchronizerErrorKey: @"Synchronization was canceled"}]];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerWillUploadChangesNotification object:self];
        [self uploadChangesWithCompletion:^(NSError *error) {
            if (error) {
                [self finishSynchronizationWithError:error];
            } else {
                [self synchronizationUpdateServerToken];
            }
        }];
    }
}

- (void)synchronizationUpdateServerToken
{
    [self updateServerTokenWithCompletion:^(BOOL needToFetchFullChanges, NSError *error) {
        if (error) {
            [self finishSynchronizationWithError:error];
        } else {
            if (needToFetchFullChanges) {
                //There were changes before we finished, repeat process again
                [self performSynchronization];
            } else {
                [self saveServerChangeToken:self.serverChangeToken];
                [self finishSynchronizationWithError:nil];
            }
        }
    }];
}

- (void)finishSynchronizationWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.syncing = NO;
        self.cancelSync = NO;

        [self.changeManager didFinishImportWithError:error];
        if (error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerDidFailToSynchronizeNotification
                                                                object:self
                                                              userInfo:@{QSCloudKitSynchronizerErrorKey : error}];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerDidSynchronizeNotification object:self];
        }
        
        callBlockIfNotNil(self.completion, error);
        self.completion = nil;
        
        DLog(@"QSCloudKitSynchronizer >> Finishing synchronization");
    });
}

#pragma mark - CloudKit calls

- (void)restoreServerChangeToken
{
    NSData *encodedToken = [[NSUserDefaults standardUserDefaults] objectForKey:QSCloudKitFetchChangesServerTokenKey];
    if (encodedToken) {
        self.serverChangeToken = [NSKeyedUnarchiver unarchiveObjectWithData:encodedToken];
    }
}

- (void)saveServerChangeToken:(CKServerChangeToken *)token
{
    NSData *encodedToken = [NSKeyedArchiver archivedDataWithRootObject:token];
    [[NSUserDefaults standardUserDefaults] setObject:encodedToken forKey:QSCloudKitFetchChangesServerTokenKey];
}

- (void)uploadChangesWithCompletion:(void(^)(NSError *error))completion
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[NSError errorWithDomain:@"QSCloudKitSynchronizer" code:0 userInfo:@{QSCloudKitSynchronizerErrorKey: @"Synchronization was canceled"}]];
    } else {
        [self uploadEntitiesWithCompletion:^(NSInteger count, BOOL pendingUploads, NSError *error) {
            if (error) {
                callBlockIfNotNil(completion, error);
            } else {
                if (pendingUploads) {
                    [self uploadChangesWithCompletion:completion];
                } else {
                    [self removeDeletedEntitiesWithCompletion:completion];
                }
            }
        }];
    }
}

- (void)uploadEntitiesWithCompletion:(void(^)(NSInteger count, BOOL pendingUploads, NSError *error))completion
{
    NSArray *records = [self.changeManager recordsToUploadWithLimit:self.batchSize];
    NSInteger recordCount = records.count;
    NSInteger requestedBatchSize = self.batchSize;
    if (recordCount == 0) {
        completion(0, NO, nil);
    } else {
        __weak QSCloudKitSynchronizer *weakSelf = self;
        //Add device UUID
        [self addDeviceUUIDToRecords:records];
        //Now perform the operation
        CKModifyRecordsOperation *modifyRecordsOperation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:records recordIDsToDelete:nil];
        
        modifyRecordsOperation.perRecordCompletionBlock = ^(CKRecord *record, NSError *error) {
            if (error.code == CKErrorServerRecordChanged) {
                //Update local data with server
                CKRecord *record = error.userInfo[CKRecordChangedErrorServerRecordKey];
                [weakSelf.changeManager saveChangesInRecord:record];
            }
        };
        
        modifyRecordsOperation.modifyRecordsCompletionBlock = ^(NSArray <CKRecord *> *savedRecords, NSArray <CKRecordID *> *deletedRecordIDs, NSError *operationError) {
            [weakSelf.changeManager didUploadRecords:savedRecords];
            
            if (operationError.code == CKErrorLimitExceeded) {
                self.batchSize = self.batchSize / 2;
            } else if (self.batchSize < QSDefaultBatchSize) {
                self.batchSize++;
            }
            
            DLog(@"QSCloudKitSynchronizer >> Uploaded %ld records", (unsigned long)savedRecords.count);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                callBlockIfNotNil(completion, savedRecords.count, recordCount >= requestedBatchSize, operationError);
            });
        };
        
        [self.database addOperation:modifyRecordsOperation];
    }
}

- (void)addDeviceUUIDToRecords:(NSArray *)records
{
    for (CKRecord *record in records) {
        record[QSCloudKitDeviceUUIDKey] = self.deviceIdentifier;
    }
}

- (void)removeDeletedEntitiesWithCompletion:(void(^)(NSError *error))completion
{
    NSArray *recordIDs = [self.changeManager recordIDsMarkedForDeletion];
    
    if (recordIDs.count == 0) {
        callBlockIfNotNil(completion, nil);
    } else {
        //Now perform the operation
        CKModifyRecordsOperation *modifyRecordsOperation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:nil recordIDsToDelete:recordIDs];
        modifyRecordsOperation.modifyRecordsCompletionBlock = ^(NSArray <CKRecord *> *savedRecords, NSArray <CKRecordID *> *deletedRecordIDs, NSError *operationError) {
            
            DLog(@"QSCloudKitSynchronizer >> Deleted %ld records", (unsigned long)deletedRecordIDs.count);
            
            [self.changeManager didDeleteRecordIDs:deletedRecordIDs];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                callBlockIfNotNil(completion, operationError);
            });
        };
        
        [self.database addOperation:modifyRecordsOperation];
    }
}

- (void)fetchChangesWithCompletion:(void(^)(NSError *error))completion
{
    CKFetchRecordChangesOperation *recordChangesOperation = [[CKFetchRecordChangesOperation alloc] initWithRecordZoneID:self.customZoneID previousServerChangeToken:self.serverChangeToken];
    __weak CKFetchRecordChangesOperation *weakOperation = recordChangesOperation;
    __weak QSCloudKitSynchronizer *weakSelf = self;
    __block NSInteger changeCount = 0;
    
    recordChangesOperation.recordChangedBlock = ^(CKRecord *record) {
        [weakSelf.changeManager saveChangesInRecord:record];
        changeCount++;
    };
    
    recordChangesOperation.recordWithIDWasDeletedBlock = ^(CKRecordID *recordID) {
        [weakSelf.changeManager deleteRecordWithID:recordID];
        changeCount++;
    };
    
    recordChangesOperation.fetchRecordChangesCompletionBlock = ^(CKServerChangeToken *serverChangeToken, NSData *clientChangeTokenData, NSError *operationError) {
        
        if (operationError.code == CKErrorChangeTokenExpired) {
            self.serverChangeToken = nil;
            [self saveServerChangeToken:self.serverChangeToken];
        } else if (serverChangeToken) {
            self.serverChangeToken = serverChangeToken;
        }
        
        if (changeCount) {
            DLog(@"QSCloudKitSynchronizer >> Downloaded %ld changes", (unsigned long)changeCount);
        }
        
        if (weakOperation.moreComing && !operationError) {
            if (weakSelf.cancelSync) {
                callBlockIfNotNil(completion, [NSError errorWithDomain:@"QSCloudKitSynchronizer" code:0 userInfo:@{QSCloudKitSynchronizerErrorKey: @"Synchronization was canceled"}]);
            } else {
                [weakSelf fetchChangesWithCompletion:completion];
            }
        } else {
            callBlockIfNotNil(completion, operationError);
        }
    };
    
    [self.database addOperation:recordChangesOperation];
}

- (void)updateServerTokenWithCompletion:(void(^)(BOOL needToFetchFullChanges, NSError *error))completion
{
    CKFetchRecordChangesOperation *recordChangesOperation = [[CKFetchRecordChangesOperation alloc] initWithRecordZoneID:self.customZoneID previousServerChangeToken:self.serverChangeToken];
    __weak CKFetchRecordChangesOperation *weakOperation = recordChangesOperation;
    __weak QSCloudKitSynchronizer *weakSelf = self;
    __block BOOL hasChanged = NO;
    
    recordChangesOperation.desiredKeys = @[@"recordID", @"modificationDate"];
    
    recordChangesOperation.recordChangedBlock = ^(CKRecord *record) {
        if ([record[QSCloudKitDeviceUUIDKey] isEqual:self.deviceIdentifier] == NO) {
            hasChanged = YES;
        }
    };
    
    recordChangesOperation.recordWithIDWasDeletedBlock = ^(CKRecordID *recordID) {
        if ([weakSelf.changeManager hasRecordID:recordID]) {
            hasChanged = YES;
        }
    };
    
    recordChangesOperation.fetchRecordChangesCompletionBlock = ^(CKServerChangeToken *serverChangeToken, NSData *clientChangeTokenData, NSError *operationError) {
        if (hasChanged) {
            DLog(@"QSCloudKitSynchronizer >> Detected changes after synchronization. Initiating sync");
            callBlockIfNotNil(completion, YES, operationError);
        } else {
            if (serverChangeToken) {
                self.serverChangeToken = serverChangeToken;
            }
            
            if (weakOperation.moreComing) {
                [weakSelf updateServerTokenWithCompletion:completion];
            } else {
                callBlockIfNotNil(completion, NO, operationError);
            }
        }
    };
    
    [self.database addOperation:recordChangesOperation];
}

- (void)subscribeForChangesInRecordZoneWithCompletion:(void(^)(NSError *error))completion
{
    if ([[NSUserDefaults standardUserDefaults] objectForKey:QSSubscriptionIdentifierKey]) {
        callBlockIfNotNil(completion, nil);
        return;
    }
    
    CKSubscription *subscription = [[CKSubscription alloc] initWithZoneID:self.customZoneID options:0];
    
    CKNotificationInfo *notificationInfo = [[CKNotificationInfo alloc] init];
    notificationInfo.shouldSendContentAvailable = YES;
    subscription.notificationInfo = notificationInfo;
    
    [self.database saveSubscription:subscription completionHandler:^(CKSubscription * _Nullable subscription, NSError * _Nullable error) {
        if (!error) {
            [[NSUserDefaults standardUserDefaults] setObject:subscription.subscriptionID forKey:QSSubscriptionIdentifierKey];
        }
        callBlockIfNotNil(completion, error);
    }];
}

- (void)cancelSubscriptionForChangesInRecordZoneWithCompletion:(void(^)(NSError *error))completion
{
    NSString *subscriptionID = [[NSUserDefaults standardUserDefaults] objectForKey:QSSubscriptionIdentifierKey];
    if (!subscriptionID) {
        callBlockIfNotNil(completion, nil);
        return;
    }
    
    [self.database deleteSubscriptionWithID:subscriptionID completionHandler:^(NSString * _Nullable subscriptionID, NSError * _Nullable error) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:QSSubscriptionIdentifierKey];
        callBlockIfNotNil(completion, error);
    }];
}

@end
