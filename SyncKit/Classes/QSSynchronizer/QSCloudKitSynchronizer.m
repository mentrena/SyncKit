//
//  QSCloudKitHelper.m
//  Quikstudy
//
//  Created by Manuel Entrena on 26/05/2016.
//  Copyright © 2016 Manuel Entrena. All rights reserved.
//

#import "QSCloudKitSynchronizer.h"
#import "SyncKitLog.h"
#import <CloudKit/CloudKit.h>

#define callBlockIfNotNil(block, ...) if (block){block(__VA_ARGS__);}

NSString * const QSCloudKitSynchronizerErrorDomain = @"QSCloudKitSynchronizerErrorDomain";
NSString * const QSCloudKitSynchronizerWillSynchronizeNotification = @"QSCloudKitSynchronizerWillSynchronizeNotification";
NSString * const QSCloudKitSynchronizerWillFetchChangesNotification = @"QSCloudKitSynchronizerWillFetchChangesNotification";
NSString * const QSCloudKitSynchronizerWillUploadChangesNotification = @"QSCloudKitSynchronizerWillUploadChangesNotification";
NSString * const QSCloudKitSynchronizerDidSynchronizeNotification = @"QSCloudKitSynchronizerDidSynchronizeNotification";
NSString * const QSCloudKitSynchronizerDidFailToSynchronizeNotification = @"QSCloudKitSynchronizerDidFailToSynchronizeNotification";
NSString * const QSCloudKitSynchronizerErrorKey = @"QSCloudKitSynchronizerErrorKey";

static NSString * QSSubscriptionIdentifierKey = @"QSSubscriptionIdentifierKey";
static const NSInteger QSDefaultBatchSize = 100;
static NSString * const QSCloudKitFetchChangesServerTokenKey = @"QSCloudKitFetchChangesServerTokenKey";
static NSString * const QSCloudKitCustomZoneCreatedKey = @"QSCloudKitCustomZoneCreatedKey";
NSString * const QSCloudKitDeviceUUIDKey = @"QSCloudKitDeviceUUIDKey";
NSString * const QSCloudKitModelCompatibilityVersionKey = @"QSCloudKitModelCompatibilityVersionKey";

@interface QSCloudKitSynchronizer ()

@property (nonatomic, readwrite, copy) NSString *containerIdentifier;

@property (nonatomic, strong) CKServerChangeToken *serverChangeToken;

@property (nonatomic, strong) CKDatabase *database;
@property (nonatomic, strong) CKRecordZoneID *customZoneID;
@property (nonatomic, strong) CKRecordZone *customZone;
@property (nonatomic, strong, readwrite) NSString *suiteName;
@property (atomic, readwrite, assign, getter=isSyncing) BOOL syncing;

@property (nonatomic, assign) NSInteger batchSize;

@property (nonatomic, strong, readwrite) id<QSChangeManager> changeManager;
@property (nonatomic, strong) NSString *deviceIdentifier;

@property (nonatomic, assign) BOOL cancelSync;

@property (nonatomic, copy) void(^completion)(NSError *error);
@property (nonatomic, weak) CKOperation *currentOperation;

@property (nonatomic, strong) dispatch_queue_t dispatchQueue;

@property (nonatomic, strong) NSUserDefaults *userDefaults;

@end

@implementation QSCloudKitSynchronizer

- (instancetype)initWithContainerIdentifier:(NSString *)containerIdentifier recordZoneID:(CKRecordZoneID *)zoneID changeManager:(id<QSChangeManager>)changeManager
{
    return [self initWithContainerIdentifier:containerIdentifier recordZoneID:zoneID changeManager:changeManager suiteName:nil];
}

- (instancetype)initWithContainerIdentifier:(NSString *)containerIdentifier recordZoneID:(CKRecordZoneID *)zoneID changeManager:(id<QSChangeManager>)changeManager suiteName:(NSString *)suiteName
{
    self = [super init];
    if (self) {
        self.containerIdentifier = containerIdentifier;
        self.customZoneID = zoneID;
        self.changeManager = changeManager;
        self.suiteName = suiteName;
        self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.suiteName];
        
        self.batchSize = QSDefaultBatchSize;
        self.compatibilityVersion = 0;
        self.syncMode = QSCloudKitSynchronizeModeSync;
        CKContainer *container = [CKContainer containerWithIdentifier:self.containerIdentifier];
        
        if (!container) {
            return nil;
        }
        
        self.database = [container privateCloudDatabase];
        self.dispatchQueue = dispatch_queue_create("QSCloudKitSynchronizer", 0);
    }
    return self;
}

- (NSString *)userDefaultsKeyForKey:(NSString *)key
{
    return [self.containerIdentifier stringByAppendingString:key];
}

- (NSString *)deviceIdentifier
{
    if (!_deviceIdentifier) {
        
        _deviceIdentifier = [self.userDefaults objectForKey:[self userDefaultsKeyForKey:QSCloudKitDeviceUUIDKey]];
        if (!_deviceIdentifier) {
            NSUUID *UUID = [NSUUID UUID];
            _deviceIdentifier = [UUID UUIDString];
            [self.userDefaults setObject:_deviceIdentifier forKey:[self userDefaultsKeyForKey:QSCloudKitDeviceUUIDKey]];
        }
    }
    return _deviceIdentifier;
}

- (void)setupCustomZoneWithCompletion:(void(^)(NSError *error))completionBlock
{
    if (!self.customZone) {
        [self.database fetchRecordZoneWithID:self.customZoneID completionHandler:^(CKRecordZone * _Nullable zone, NSError * _Nullable error) {
            
            if (zone) {
                DLog(@"QSCloudKitSynchronizer >> Fetched custom record zone");
                self.customZone = zone;
                [self.userDefaults setBool:YES forKey:[self userDefaultsKeyForKey:QSCloudKitCustomZoneCreatedKey]];
                callBlockIfNotNil(completionBlock, error);
            } else if (error.code  == CKErrorZoneNotFound &&
                       [self.userDefaults boolForKey:[self userDefaultsKeyForKey:QSCloudKitCustomZoneCreatedKey]] == NO) {
                self.customZone = [[CKRecordZone alloc] initWithZoneID:self.customZoneID];
                [self.database saveRecordZone:self.customZone completionHandler:^(CKRecordZone * _Nullable zone, NSError * _Nullable error) {
                    if (!error && zone) {
                        DLog(@"QSCloudKitSynchronizer >> Created custom record zone");
                        self.customZone = zone;
                        [self.userDefaults setBool:YES forKey:[self userDefaultsKeyForKey:QSCloudKitCustomZoneCreatedKey]];
                    }
                    callBlockIfNotNil(completionBlock, error);
                }];
            } else {
                callBlockIfNotNil(completionBlock, error);
            }
            
        }];
    } else {
        callBlockIfNotNil(completionBlock, nil);
    }
}

#pragma mark - Public

+ (NSArray<NSString *> *)synchronizerMetadataKeys
{
    static NSArray *metadataKeys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        metadataKeys = @[QSCloudKitDeviceUUIDKey, QSCloudKitModelCompatibilityVersionKey];
    });
    return metadataKeys;
}

- (void)synchronizeWithCompletion:(void(^)(NSError *error))completion
{
    if (self.isSyncing) {
        callBlockIfNotNil(completion, [NSError errorWithDomain:QSCloudKitSynchronizerErrorDomain code:QSCloudKitSynchronizerErrorAlreadySyncing userInfo:nil]);
        return;
    }
    
    DLog(@"QSCloudKitSynchronizer >> Initiating synchronization");
    self.cancelSync = NO;
    self.syncing = YES;
    
    if (!self.customZone) {
        __weak QSCloudKitSynchronizer *weakSelf = self;
        [self setupCustomZoneWithCompletion:^(NSError *error) {
            if (error) {
                weakSelf.syncing = NO;
                callBlockIfNotNil(completion, error);
                
                if (weakSelf) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerDidFailToSynchronizeNotification
                                                                            object:weakSelf
                                                                          userInfo:@{QSCloudKitSynchronizerErrorKey : error}];
                    });
                }
            } else {
                weakSelf.completion = completion;
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
    if (self.isSyncing) {
        self.cancelSync = YES;
        [self.currentOperation cancel];
    }
}

- (void)eraseLocal
{
    [self.userDefaults removeObjectForKey:[self userDefaultsKeyForKey:QSCloudKitFetchChangesServerTokenKey]];
    [self.userDefaults removeObjectForKey:[self userDefaultsKeyForKey:QSSubscriptionIdentifierKey]];
    [self.userDefaults removeObjectForKey:[self userDefaultsKeyForKey:QSCloudKitCustomZoneCreatedKey]];
    [self.userDefaults removeObjectForKey:[self userDefaultsKeyForKey:QSCloudKitDeviceUUIDKey]];
    
    [self.changeManager deleteChangeTracking];
}

- (void)eraseRemoteAndLocalDataWithCompletion:(void(^)(NSError *error))completion
{
    __weak QSCloudKitSynchronizer *weakSelf = self;
    [self.database deleteRecordZoneWithID:self.customZoneID completionHandler:^(CKRecordZoneID * _Nullable zoneID, NSError * _Nullable error) {
        if (!error) {
            weakSelf.customZone = nil;
            DLog(@"QSCloudKitSynchronizer >> Deleted zone");
            [weakSelf eraseLocal];
        } else {
            DLog(@"QSCloudKitSynchronizer >> Error: %@", error);
        }
        callBlockIfNotNil(completion, error);
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
    dispatch_async(self.dispatchQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerWillSynchronizeNotification object:self];
        });
        
        [self.changeManager prepareForImport];
        [self restoreServerChangeToken];
        [self synchronizationFetchChanges];
    });
}

- (void)synchronizationFetchChanges
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[NSError errorWithDomain:@"QSCloudKitSynchronizer" code:0 userInfo:@{QSCloudKitSynchronizerErrorKey: @"Synchronization was canceled"}]];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerWillFetchChangesNotification object:self];
        });
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
            dispatch_async(self.dispatchQueue, ^{
                if (error) {
                    [self finishSynchronizationWithError:error];
                } else {
                    [self saveServerChangeToken:self.serverChangeToken];
                    
                    if (self.syncMode == QSCloudKitSynchronizeModeSync) {
                        [self synchronizationUploadChanges];
                    } else {
                        [self finishSynchronizationWithError:nil];
                    }
                }
            });
        }];
    }
}

- (void)synchronizationUploadChanges
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[NSError errorWithDomain:@"QSCloudKitSynchronizer" code:0 userInfo:@{QSCloudKitSynchronizerErrorKey: @"Synchronization was canceled"}]];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerWillUploadChangesNotification object:self];
        });
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
    self.syncing = NO;
    self.cancelSync = NO;
    
    [self.changeManager didFinishImportWithError:error];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerDidFailToSynchronizeNotification
                                                                object:self
                                                              userInfo:@{QSCloudKitSynchronizerErrorKey : error}];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerDidSynchronizeNotification object:self];
        }
        
        callBlockIfNotNil(self.completion, error);
        self.completion = nil;
    });
    
    DLog(@"QSCloudKitSynchronizer >> Finishing synchronization");
}

#pragma mark - CloudKit calls

- (void)restoreServerChangeToken
{
    NSData *encodedToken = [self.userDefaults objectForKey:[self userDefaultsKeyForKey:QSCloudKitFetchChangesServerTokenKey]];
    if (encodedToken) {
        self.serverChangeToken = [NSKeyedUnarchiver unarchiveObjectWithData:encodedToken];
    }
}

- (void)saveServerChangeToken:(CKServerChangeToken *)token
{
    NSData *encodedToken = [NSKeyedArchiver archivedDataWithRootObject:token];
    [self.userDefaults setObject:encodedToken forKey:[self userDefaultsKeyForKey:QSCloudKitFetchChangesServerTokenKey]];
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
                    [self uploadDeletionsWithCompletion:completion];
                }
            }
        }];
    }
}

- (void)uploadDeletionsWithCompletion:(void(^)(NSError *error))completion
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[NSError errorWithDomain:@"QSCloudKitSynchronizer" code:0 userInfo:@{QSCloudKitSynchronizerErrorKey: @"Synchronization was canceled"}]];
    } else {
        [self removeDeletedEntitiesWithCompletion:^(NSInteger count, BOOL pendingUploads, NSError *error) {
            if (error) {
                callBlockIfNotNil(completion, error);
            } else {
                if (pendingUploads) {
                    [self uploadDeletionsWithCompletion:completion];
                } else {
                    callBlockIfNotNil(completion, nil);
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
        callBlockIfNotNil(completion, 0, NO, nil);
    } else {
        __weak QSCloudKitSynchronizer *weakSelf = self;
        //Add metadata: device UUID and model version
        [self addMetadataToRecords:records];
        //Now perform the operation
        CKModifyRecordsOperation *modifyRecordsOperation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:records recordIDsToDelete:nil];
        
        NSMutableArray *recordsToSave = [NSMutableArray array];
        modifyRecordsOperation.perRecordCompletionBlock = ^(CKRecord *record, NSError *error) {
            dispatch_async(self.dispatchQueue, ^{
                if (error.code == CKErrorServerRecordChanged) {
                    //Update local data with server
                    CKRecord *record = error.userInfo[CKRecordChangedErrorServerRecordKey];
                    if (record) {
                        [recordsToSave addObject:record];
                    }
                }
            });
        };
        
        modifyRecordsOperation.modifyRecordsCompletionBlock = ^(NSArray <CKRecord *> *savedRecords, NSArray <CKRecordID *> *deletedRecordIDs, NSError *operationError) {
            dispatch_async(self.dispatchQueue, ^{
                [weakSelf.changeManager saveChangesInRecords:recordsToSave];
                [weakSelf.changeManager didUploadRecords:savedRecords];
                
                DLog(@"QSCloudKitSynchronizer >> Uploaded %ld records", (unsigned long)savedRecords.count);
                
                if (operationError.code == CKErrorLimitExceeded) {
                    self.batchSize = self.batchSize / 2;
                } else if (self.batchSize < QSDefaultBatchSize) {
                    self.batchSize++;
                }
                
                callBlockIfNotNil(completion, savedRecords.count, recordCount >= requestedBatchSize, operationError);
            });
        };
        
        self.currentOperation = modifyRecordsOperation;
        [self.database addOperation:modifyRecordsOperation];
    }
}

- (void)addMetadataToRecords:(NSArray *)records
{
    for (CKRecord *record in records) {
        record[QSCloudKitDeviceUUIDKey] = self.deviceIdentifier;
        if (self.compatibilityVersion > 0) {
            record[QSCloudKitModelCompatibilityVersionKey] = @(self.compatibilityVersion);
        }
    }
}

- (void)removeDeletedEntitiesWithCompletion:(void(^)(NSInteger count, BOOL pendingUploads, NSError *error))completion
{
    NSArray *recordIDs = [self.changeManager recordIDsMarkedForDeletionWithLimit:self.batchSize];
    NSInteger recordCount = recordIDs.count;
    NSInteger requestedBatchSize = self.batchSize;
    
    if (recordCount == 0) {
        callBlockIfNotNil(completion, 0, NO, nil);
    } else {
        //Now perform the operation
        CKModifyRecordsOperation *modifyRecordsOperation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:nil recordIDsToDelete:recordIDs];
        modifyRecordsOperation.modifyRecordsCompletionBlock = ^(NSArray <CKRecord *> *savedRecords, NSArray <CKRecordID *> *deletedRecordIDs, NSError *operationError) {
            dispatch_async(self.dispatchQueue, ^{
                DLog(@"QSCloudKitSynchronizer >> Deleted %ld records", (unsigned long)deletedRecordIDs.count);
                
                if (operationError.code == CKErrorLimitExceeded) {
                    self.batchSize = self.batchSize / 2;
                } else if (self.batchSize < QSDefaultBatchSize) {
                    self.batchSize++;
                }
                
                [self.changeManager didDeleteRecordIDs:deletedRecordIDs];
                
                callBlockIfNotNil(completion, deletedRecordIDs.count, recordCount >= requestedBatchSize, operationError);
            });
        };
        
        self.currentOperation = modifyRecordsOperation;
        [self.database addOperation:modifyRecordsOperation];
    }
}

- (void)fetchChangesWithCompletion:(void(^)(NSError *error))completion
{
    __weak QSCloudKitSynchronizer *weakSelf = self;
    
    __block CKFetchRecordChangesOperation *recordChangesOperation = [[CKFetchRecordChangesOperation alloc] initWithRecordZoneID:self.customZoneID previousServerChangeToken:self.serverChangeToken];
    __block NSInteger changeCount = 0;
    __block BOOL higherModelVersionFound = NO;
    
    NSMutableArray *recordsToSave = [NSMutableArray array];
    NSMutableArray *recordIDsToDelete = [NSMutableArray array];
    
    recordChangesOperation.recordChangedBlock = ^(CKRecord *record) {
        dispatch_async(self.dispatchQueue, ^{
            if ([record[QSCloudKitDeviceUUIDKey] isEqual:self.deviceIdentifier] == NO) {
                NSNumber *version = record[QSCloudKitModelCompatibilityVersionKey];
                if (self.compatibilityVersion > 0 && [version integerValue] > self.compatibilityVersion) {
                    higherModelVersionFound = YES;
                } else {
                    [recordsToSave addObject:record];
                }
            }
            changeCount++;
        });
    };
    
    recordChangesOperation.recordWithIDWasDeletedBlock = ^(CKRecordID *recordID) {
        dispatch_async(self.dispatchQueue, ^{
            [recordIDsToDelete addObject:recordID];
            changeCount++;
        });
    };
    
    recordChangesOperation.fetchRecordChangesCompletionBlock = ^(CKServerChangeToken *serverChangeToken, NSData *clientChangeTokenData, NSError *operationError) {
        
        dispatch_async(self.dispatchQueue, ^{
            if (operationError.code == CKErrorChangeTokenExpired) {
                weakSelf.serverChangeToken = nil;
                [weakSelf saveServerChangeToken:self.serverChangeToken];
            } else if (serverChangeToken) {
                weakSelf.serverChangeToken = serverChangeToken;
            }
            
            if (changeCount) {
                DLog(@"QSCloudKitSynchronizer >> Downloaded %ld changes", (unsigned long)changeCount);
            }
            
            if (higherModelVersionFound) {
                DLog(@"QSCloudKitSynchronizer >> Some downloaded records were uploaded with a newer version of the model. Canceling synchronization");
                callBlockIfNotNil(completion, [NSError errorWithDomain:QSCloudKitSynchronizerErrorDomain code:QSCloudKitSynchronizerErrorHigherModelVersionFound userInfo:@{QSCloudKitSynchronizerErrorKey: @"Some downloaded records were uploaded with a newer version of the model"}]);
            } else {
                [weakSelf.changeManager saveChangesInRecords:recordsToSave];
                [weakSelf.changeManager deleteRecordsWithIDs:recordIDsToDelete];
                
                if (recordChangesOperation.moreComing && !operationError) {
                    if (weakSelf.cancelSync) {
                        callBlockIfNotNil(completion, [NSError errorWithDomain:QSCloudKitSynchronizerErrorDomain code:0 userInfo:@{QSCloudKitSynchronizerErrorKey: @"Synchronization was canceled"}]);
                    } else {
                        [weakSelf fetchChangesWithCompletion:completion];
                    }
                } else {
                    callBlockIfNotNil(completion, operationError);
                }
                
                recordChangesOperation = nil;
            }
        });
    };
    
    self.currentOperation = recordChangesOperation;
    [self.database addOperation:recordChangesOperation];
}

- (void)updateServerTokenWithCompletion:(void(^)(BOOL needToFetchFullChanges, NSError *error))completion
{
    CKFetchRecordChangesOperation *recordChangesOperation = [[CKFetchRecordChangesOperation alloc] initWithRecordZoneID:self.customZoneID previousServerChangeToken:self.serverChangeToken];
    __weak CKFetchRecordChangesOperation *weakOperation = recordChangesOperation;
    __weak QSCloudKitSynchronizer *weakSelf = self;
    __block BOOL hasChanged = NO;
    
    recordChangesOperation.desiredKeys = @[@"recordID", QSCloudKitDeviceUUIDKey];
    
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
        dispatch_async(self.dispatchQueue, ^{
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
        });
    };
    
    self.currentOperation = recordChangesOperation;
    [self.database addOperation:recordChangesOperation];
}

- (void)subscribeForChangesInRecordZoneWithCompletion:(void(^)(NSError *error))completion
{
    if ([self subscriptionID] != nil) {
        callBlockIfNotNil(completion, nil);
        return;
    } else {
        // Check if existing subscription already in place
        [self.database fetchAllSubscriptionsWithCompletionHandler:^(NSArray<CKSubscription *> * _Nullable subscriptions, NSError * _Nullable error) {
            if (error) {
                callBlockIfNotNil(completion, error);
            } else {
                NSString *existingSubscriptionIdentifier = nil;
                for (CKSubscription *subscription in subscriptions) {
                    if (subscription.subscriptionType == CKSubscriptionTypeRecordZone) {
                        existingSubscriptionIdentifier = subscription.subscriptionID;
                    }
                }
                
                if (existingSubscriptionIdentifier) {
                    // Found existing subscription
                    [self.userDefaults setObject:existingSubscriptionIdentifier forKey:[self userDefaultsKeyForKey:QSSubscriptionIdentifierKey]];
                    callBlockIfNotNil(completion, nil);
                } else {
                    // Create new one
                    CKSubscription *subscription = [[CKSubscription alloc] initWithZoneID:self.customZoneID options:0];
                    
                    CKNotificationInfo *notificationInfo = [[CKNotificationInfo alloc] init];
                    notificationInfo.shouldSendContentAvailable = YES;
                    subscription.notificationInfo = notificationInfo;
                    
                    [self.database saveSubscription:subscription completionHandler:^(CKSubscription * _Nullable subscription, NSError * _Nullable error) {
                        if (!error) {
                            [self.userDefaults setObject:subscription.subscriptionID forKey:[self userDefaultsKeyForKey:QSSubscriptionIdentifierKey]];
                        }
                        
                        callBlockIfNotNil(completion, error);
                    }];

                }
            }
        }];
    }
    
}

- (void)cancelSubscriptionForChangesInRecordZoneWithCompletion:(void(^)(NSError *error))completion
{
    NSString *subscriptionID = [self.userDefaults objectForKey:[self userDefaultsKeyForKey:QSSubscriptionIdentifierKey]];
    
    if (subscriptionID) {
        [self cancelSubscriptionWithID:subscriptionID withCompletion:completion];
    } else {
        // There might be an existing subscription in the server
        [self.database fetchAllSubscriptionsWithCompletionHandler:^(NSArray<CKSubscription *> * _Nullable subscriptions, NSError * _Nullable error) {
            if (error) {
                callBlockIfNotNil(completion, error);
            } else {
                NSString *subscriptionID = nil;
                for (CKSubscription *subscription in subscriptions) {
                    if (subscription.subscriptionType == CKSubscriptionTypeRecordZone) {
                        subscriptionID = subscription.subscriptionID;
                        break;
                    }
                }
                
                if (subscriptionID) {
                    [self cancelSubscriptionWithID:subscriptionID withCompletion:completion];
                } else {
                    // No subscription to cancel
                    callBlockIfNotNil(completion, nil);
                }
            }
        }];
    }
}

- (void)cancelSubscriptionWithID:(NSString *)subscriptionID withCompletion:(void(^)(NSError *error))completion
{
    [self.database deleteSubscriptionWithID:subscriptionID completionHandler:^(NSString * _Nullable subscriptionID, NSError * _Nullable error) {
        [self.userDefaults removeObjectForKey:[self userDefaultsKeyForKey:QSSubscriptionIdentifierKey]];
        callBlockIfNotNil(completion, error);
    }];
}

- (NSString *)subscriptionID
{
    return [self.userDefaults objectForKey:[self userDefaultsKeyForKey:QSSubscriptionIdentifierKey]];
}

@end
