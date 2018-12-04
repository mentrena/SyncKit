//
//  QSCloudKitHelper.m
//  Quikstudy
//
//  Created by Manuel Entrena on 26/05/2016.
//  Copyright © 2016 Manuel Entrena. All rights reserved.
//

#import "QSCloudKitSynchronizer.h"
#import "SyncKitLog.h"
#import "QSBackupDetection.h"
#import "QSCloudKitSynchronizer+Private.h"
#import <SyncKit/SyncKit-Swift.h>
#import <CloudKit/CloudKit.h>

#define callBlockIfNotNil(block, ...) if (block){block(__VA_ARGS__);}

NSString * const QSCloudKitSynchronizerErrorDomain = @"QSCloudKitSynchronizerErrorDomain";
NSString * const QSCloudKitSynchronizerWillSynchronizeNotification = @"QSCloudKitSynchronizerWillSynchronizeNotification";
NSString * const QSCloudKitSynchronizerWillFetchChangesNotification = @"QSCloudKitSynchronizerWillFetchChangesNotification";
NSString * const QSCloudKitSynchronizerWillUploadChangesNotification = @"QSCloudKitSynchronizerWillUploadChangesNotification";
NSString * const QSCloudKitSynchronizerDidSynchronizeNotification = @"QSCloudKitSynchronizerDidSynchronizeNotification";
NSString * const QSCloudKitSynchronizerDidFailToSynchronizeNotification = @"QSCloudKitSynchronizerDidFailToSynchronizeNotification";
NSString * const QSCloudKitSynchronizerErrorKey = @"QSCloudKitSynchronizerErrorKey";

static const NSInteger QSDefaultBatchSize = 200;
NSString * const QSCloudKitDeviceUUIDKey = @"QSCloudKitDeviceUUIDKey";
NSString * const QSCloudKitModelCompatibilityVersionKey = @"QSCloudKitModelCompatibilityVersionKey";

@interface QSCloudKitSynchronizer ()

@property (nonatomic, readwrite, copy) NSString *identifier;

@property (nonatomic, readwrite, copy) NSString *containerIdentifier;
@property (nonatomic, strong) CKServerChangeToken *serverChangeToken;
@property (nonatomic, strong) NSMutableDictionary *activeZoneTokens;
@property (nonatomic, readwrite, assign) BOOL usesSharedDatabase;

@property (nonatomic, strong) CKDatabase *database;
@property (atomic, readwrite, assign, getter=isSyncing) BOOL syncing;

@property (nonatomic, strong, readwrite) NSDictionary *modelAdapterDictionary;
@property (nonatomic, readwrite, strong) NSString *deviceIdentifier;

@property (nonatomic, assign) BOOL cancelSync;

@property (nonatomic, copy) void(^completion)(NSError *error);
@property (nonatomic, weak) NSOperation *currentOperation;

@property (nonatomic, readwrite, strong) dispatch_queue_t dispatchQueue;
@property (nonatomic, strong) NSOperationQueue *operationQueue;

@property (nonatomic, readwrite, strong) id<QSKeyValueStore> keyValueStore;
@property (nonatomic, readwrite, strong) id<QSCloudKitSynchronizerAdapterProvider> adapterProvider;
@property (nonatomic, assign) NSInteger maxBatchSize;

@end

@implementation QSCloudKitSynchronizer

- (instancetype)initWithIdentifier:(NSString *)identifier containerIdentifier:(NSString *)containerIdentifier database:(CKDatabase *)database adapterProvider:(id<QSCloudKitSynchronizerAdapterProvider>)adapterProvider
{
    return [self _initWithIdentifier:identifier containerIdentifier:containerIdentifier database:database adapterProvider:adapterProvider keyValueStore:[NSUserDefaults standardUserDefaults]];
}

- (instancetype)initWithIdentifier:(NSString *)identifier containerIdentifier:(NSString *)containerIdentifier database:(CKDatabase *)database adapterProvider:(id<QSCloudKitSynchronizerAdapterProvider>)adapterProvider keyValueStore:(id<QSKeyValueStore>)keyValueStore
{
    return [self _initWithIdentifier:identifier containerIdentifier:containerIdentifier database:database adapterProvider:adapterProvider keyValueStore:keyValueStore];
}

- (instancetype)_initWithIdentifier:(NSString *)identifier containerIdentifier:(NSString *)containerIdentifier database:(CKDatabase *)database adapterProvider:(id<QSCloudKitSynchronizerAdapterProvider>)adapterProvider keyValueStore:(id<QSKeyValueStore>)keyValueStore
{
    self = [super init];
    if (self) {
        self.identifier = identifier;
        self.adapterProvider = adapterProvider;
        self.keyValueStore = keyValueStore;
        self.containerIdentifier = containerIdentifier;
        self.modelAdapterDictionary = @{};
        
        self.maxBatchSize = QSDefaultBatchSize;
        self.batchSize = self.maxBatchSize;
        self.compatibilityVersion = 0;
        self.syncMode = QSCloudKitSynchronizeModeSync;
        self.database = database;
        
        [QSBackupDetection runBackupDetectionWithCompletion:^(QSBackupDetectionResult result, NSError *error) {
            if (result == QSBackupDetectionResultRestoredFromBackup) {
                [self clearDeviceIdentifier];
            }
        }];
        
        self.dispatchQueue = dispatch_queue_create("QSCloudKitSynchronizer", 0);
        self.operationQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}

- (NSString *)deviceIdentifier
{
    if (!_deviceIdentifier) {
        
        _deviceIdentifier = [self getStoredDeviceUUID];
        if (!_deviceIdentifier) {
            NSUUID *UUID = [NSUUID UUID];
            _deviceIdentifier = [UUID UUIDString];
            [self storeDeviceUUID:_deviceIdentifier];
        }
    }
    return _deviceIdentifier;
}

- (void)clearDeviceIdentifier
{
    [self storeDeviceUUID:nil];
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

    self.completion = completion;
    [self performSynchronization];
}

- (void)cancelSynchronization
{
    if (self.isSyncing) {
        self.cancelSync = YES;
        [self.currentOperation cancel];
    }
}

- (void)eraseLocalMetadata
{
    [self storeDatabaseToken:nil];
    [self clearAllStoredSubscriptionIDs];
    [self storeDeviceUUID:nil];
    
    for (id<QSModelAdapter> modelAdapter in [self.modelAdapters copy]) {
        [modelAdapter deleteChangeTracking];
        [self removeModelAdapter:modelAdapter];
    }
}

- (void)deleteRecordZoneForModelAdapter:(id<QSModelAdapter>)modelAdapter withCompletion:(void(^)(NSError *error))completion
{
    [self.database deleteRecordZoneWithID:modelAdapter.recordZoneID completionHandler:^(CKRecordZoneID * _Nullable zoneID, NSError * _Nullable error) {
        if (!error) {
            DLog(@"QSCloudKitSynchronizer >> Deleted zone: %@", zoneID);
        } else {
            DLog(@"QSCloudKitSynchronizer >> Error: %@", error);
        }
        callBlockIfNotNil(completion, error);
    }];
}

- (NSArray<id<QSModelAdapter> > *)modelAdapters
{
    return [self.modelAdapterDictionary allValues];
}

- (void)addModelAdapter:(id<QSModelAdapter>)modelAdapter
{
    NSMutableDictionary *updatedManagers = [self.modelAdapterDictionary mutableCopy];
    updatedManagers[modelAdapter.recordZoneID] = modelAdapter;
    self.modelAdapterDictionary = [updatedManagers copy];
}

- (void)removeModelAdapter:(id<QSModelAdapter>)modelAdapter
{
    NSMutableDictionary *updatedManagers = [self.modelAdapterDictionary mutableCopy];
    [updatedManagers removeObjectForKey:modelAdapter.recordZoneID];
    self.modelAdapterDictionary = [updatedManagers copy];
}

#pragma mark - Sync

- (void)performSynchronization
{
    dispatch_async(self.dispatchQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerWillSynchronizeNotification object:self];
        });
        
        for (id<QSModelAdapter> modelAdapter in self.modelAdapters) {
            [modelAdapter prepareForImport];
        }
        
        [self synchronizationFetchChanges];
    });
}

#pragma mark - 1) Fetch changes

- (void)synchronizationFetchChanges
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[self cancelError]];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerWillFetchChangesNotification object:self];
        });
        [self fetchDatabaseChangesWithCompletion:^(CKServerChangeToken *databaseToken, NSError *error) {
            if (error) {
                [self finishSynchronizationWithError:error];
            } else {
                self.serverChangeToken = databaseToken;
                if (self.syncMode == QSCloudKitSynchronizeModeSync) {
                    [self synchronizationUploadChanges];
                } else {
                    [self finishSynchronizationWithError:nil];
                }
            }
        }];
    }
}

- (void)fetchDatabaseChangesWithCompletion:(void(^)(CKServerChangeToken *databaseToken, NSError *error))completion
{
    QSFetchDatabaseChangesOperation *operation = [[QSFetchDatabaseChangesOperation alloc] initWithDatabase:self.database
                                                                                             databaseToken:self.serverChangeToken
                                                                                                completion:^(CKServerChangeToken * _Nullable databaseToken, NSArray<CKRecordZoneID *> * _Nonnull changedZoneIDs, NSArray<CKRecordZoneID *> * _Nonnull deletedZoneIDs) {
        dispatch_async(self.dispatchQueue, ^{
            [self notifyProviderForDeletedZoneIDs:deletedZoneIDs];
            
            NSArray *zoneIDsToFetch = [self loadAdaptersAndTokensForZoneIDs:changedZoneIDs];
            if (zoneIDsToFetch.count) {
                
                [self fetchZoneChanges:zoneIDsToFetch withCompletion:^(NSError *error) {
                    if (error) {
                        [self finishSynchronizationWithError:error];
                    } else {
                        [self synchronizationMergeChangesWithCompletion:^(NSError *error) {
                            [self resetActiveTokens];
                            callBlockIfNotNil(completion, databaseToken, error);
                        }];
                    }
                }];
            } else {
                [self resetActiveTokens];
                callBlockIfNotNil(completion, databaseToken, nil);
            }
            
        });
                                                                                                    
    }];
    
    [self runOperation:operation];
}

- (NSArray<CKRecordZoneID *> *)loadAdaptersAndTokensForZoneIDs:(NSArray<CKRecordZoneID *> *)zoneIDs
{
    NSMutableArray *filteredZoneIDs = [NSMutableArray array];
    self.activeZoneTokens = [NSMutableDictionary dictionary];
    
    for (CKRecordZoneID *zoneID in zoneIDs) {
        id<QSModelAdapter> modelAdapter = self.modelAdapterDictionary[zoneID];
        if (!modelAdapter) {
            id<QSModelAdapter> newModelAdapter = [self.adapterProvider cloudKitSynchronizer:self modelAdapterForRecordZoneID:zoneID];
            if (newModelAdapter) {
                modelAdapter = newModelAdapter;
                NSMutableDictionary *updatedManagers = [self.modelAdapterDictionary mutableCopy];
                updatedManagers[zoneID] = newModelAdapter;
                [newModelAdapter prepareForImport];
                self.modelAdapterDictionary = [updatedManagers copy];
            }
        }
        if (modelAdapter) {
            [filteredZoneIDs addObject:zoneID];
            self.activeZoneTokens[zoneID] = [modelAdapter serverChangeToken];
        }
    }
    
    return [filteredZoneIDs copy];
}

- (void)resetActiveTokens
{
    self.activeZoneTokens = [NSMutableDictionary dictionary];
}

- (void)fetchZoneChanges:(NSArray *)zoneIDs withCompletion:(void(^)(NSError *error))completion
{
    void (^completionBlock)(NSDictionary<CKRecordZoneID *,QSFetchZoneChangesOperationZoneResult *> * _Nonnull zoneResults) = ^(NSDictionary<CKRecordZoneID *,QSFetchZoneChangesOperationZoneResult *> * _Nonnull zoneResults) {
       
        dispatch_async(self.dispatchQueue, ^{
            NSMutableArray *pendingZones = [NSMutableArray array];
            __block NSError *error = nil;
            [zoneResults enumerateKeysAndObjectsUsingBlock:^(CKRecordZoneID * _Nonnull zoneID, QSFetchZoneChangesOperationZoneResult * _Nonnull zoneResult, BOOL * _Nonnull stop) {
                
                id<QSModelAdapter> modelAdapter = self.modelAdapterDictionary[zoneID];
                if (zoneResult.error) {
                    error = zoneResult.error;
                    *stop = YES;
                } else {
                    DLog(@"QSCloudKitSynchronizer >> Downloaded %ld changed records >> from zone %@", (unsigned long)zoneResult.downloadedRecords.count, zoneID);
                    DLog(@"QSCloudKitSynchronizer >> Downloaded %ld deleted record IDs >> from zone %@", (unsigned long)zoneResult.deletedRecordIDs.count, zoneID);
                    self.activeZoneTokens[zoneID] = zoneResult.serverChangeToken;
                    [modelAdapter saveChangesInRecords:zoneResult.downloadedRecords];
                    [modelAdapter deleteRecordsWithIDs:zoneResult.deletedRecordIDs];
                    if (zoneResult.moreComing) {
                        [pendingZones addObject:zoneID];
                    }
                }
            }];
            
            if (pendingZones.count && !error) {
                [self fetchZoneChanges:pendingZones withCompletion:completion];
            } else {
                callBlockIfNotNil(completion, error);
            }
        });
    };
    
    QSFetchZoneChangesOperation *operation = [[QSFetchZoneChangesOperation alloc] initWithDatabase:self.database
                                                                                           zoneIDs:zoneIDs
                                                                                  zoneChangeTokens:[self.activeZoneTokens copy]
                                                                                      modelVersion:self.compatibilityVersion
                                                                            ignoreDeviceIdentifier:nil
                                                                                       desiredKeys:nil
                                                                                        completion:completionBlock];
    [self runOperation:operation];
}

#pragma mark - 2) Merge changes

- (void)synchronizationMergeChangesWithCompletion:(void(^)(NSError *error))completion
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[self cancelError]];
    } else {
        
        NSMutableSet *modelAdapters = [NSMutableSet set];
        for (CKRecordZoneID *zoneID in self.activeZoneTokens.allKeys) {
            [modelAdapters addObject:self.modelAdapterDictionary[zoneID]];
        }
        [self mergeChanges:modelAdapters completion:^(NSError *error) {
            callBlockIfNotNil(completion, error);
        }];
    }
}

- (void)mergeChanges:(NSSet *)modelAdapters completion:(void(^)(NSError *error))completion
{
    id<QSModelAdapter> modelAdapter = [modelAdapters anyObject];
    if (!modelAdapter) {
        callBlockIfNotNil(completion, nil);
    } else {
        __weak QSCloudKitSynchronizer *weakSelf = self;
        [modelAdapter persistImportedChangesWithCompletion:^(NSError * _Nullable error) {
            NSMutableSet *pendingModelAdapters = [modelAdapters mutableCopy];
            [pendingModelAdapters removeObject:modelAdapter];
            
            if (!error) {
                [modelAdapter saveToken:self.activeZoneTokens[modelAdapter.recordZoneID]];
            }
            
            if (error) {
                callBlockIfNotNil(completion, error);
            } else {
                [weakSelf mergeChanges:[pendingModelAdapters copy] completion:completion];
            }
        }];
    }
}

#pragma mark - 3) Upload changes

- (void)synchronizationUploadChanges
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[self cancelError]];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:QSCloudKitSynchronizerWillUploadChangesNotification object:self];
        });
        [self uploadChangesWithCompletion:^(NSError *error) {

            if (error) {
                if ([self isServerRecordChangedError:error]) {
                    [self synchronizationFetchChanges];
                } else {
                    [self finishSynchronizationWithError:error];
                }
            } else {
                [self synchronizationUpdateServerTokens];
            }
        }];
    }
}

- (void)uploadChangesWithCompletion:(void(^)(NSError *error))completion
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[self cancelError]];
    } else {
        [self uploadEntitiesForModelAdapterSet:[NSSet setWithArray:self.modelAdapters] completion:^(NSError *error) {
            if (error) {
                callBlockIfNotNil(completion, error);
            } else {
                [self uploadDeletionsWithCompletion:completion];
            }
        }];
    }
}

- (void)uploadDeletionsWithCompletion:(void(^)(NSError *error))completion
{
    if (self.cancelSync) {
        [self finishSynchronizationWithError:[self cancelError]];
    } else {
        [self removeDeletedEntitiesFromModelAdapters:[NSSet setWithArray:self.modelAdapters] completion:^(NSError *error) {
            
            callBlockIfNotNil(completion, error);
        }];
    }
}

- (void)uploadEntitiesForModelAdapterSet:(NSSet *)modelAdapters completion:(void(^)(NSError *error))completion
{
    if (modelAdapters.count == 0) {
        callBlockIfNotNil(completion, nil);
    } else {
        __weak QSCloudKitSynchronizer *weakSelf = self;
        id<QSModelAdapter> modelAdapter = [modelAdapters anyObject];
        [self setupRecordZoneIfNeeded:modelAdapter completion:^(NSError *error) {
            if (error) {
                callBlockIfNotNil(completion, error);
            } else {
                
                [self uploadEntitiesForModelAdapter:modelAdapter withCompletion:^(NSError *error) {
                    
                    if (error) {
                        callBlockIfNotNil(completion, error);
                    } else {
                        NSMutableSet *pendingModelAdapters = [modelAdapters mutableCopy];
                        [pendingModelAdapters removeObject:modelAdapter];
                        [weakSelf uploadEntitiesForModelAdapterSet:pendingModelAdapters completion:completion];
                    }
                }];
            }
        }];
    }
}

- (void)uploadEntitiesForModelAdapter:(id<QSModelAdapter>)modelAdapter withCompletion:(void(^)(NSError *error))completion
{
    NSArray *records = [modelAdapter recordsToUploadWithLimit:self.batchSize];
    NSInteger recordCount = records.count;
    NSInteger requestedBatchSize = self.batchSize;
    if (recordCount == 0) {
        callBlockIfNotNil(completion, nil);
    } else {
        __weak QSCloudKitSynchronizer *weakSelf = self;
        //Add metadata: device UUID and model version
        [self addMetadataToRecords:records];
        //Now perform the operation
        CKModifyRecordsOperation *modifyRecordsOperation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:records recordIDsToDelete:nil];
        
        modifyRecordsOperation.modifyRecordsCompletionBlock = ^(NSArray <CKRecord *> *savedRecords, NSArray <CKRecordID *> *deletedRecordIDs, NSError *operationError) {
            dispatch_async(self.dispatchQueue, ^{
                
                if (!operationError) {
                    
                    if (self.batchSize < self.maxBatchSize) {
                        self.batchSize += 5;
                    }
                    
                    [modelAdapter didUploadRecords:savedRecords];
                    
                    DLog(@"QSCloudKitSynchronizer >> Uploaded %ld records", (unsigned long)savedRecords.count);
                    
                    if (recordCount >= requestedBatchSize) {
                        [weakSelf uploadEntitiesForModelAdapter:modelAdapter withCompletion:completion];
                    } else {
                        callBlockIfNotNil(completion, operationError);
                    }
                } else {
                    if ([self isLimitExceededError:operationError]) {
                        self.batchSize = self.batchSize / 2;
                    }
                    
                    callBlockIfNotNil(completion, operationError);
                }
            });
        };
        
        self.currentOperation = modifyRecordsOperation;
        [self.database addOperation:modifyRecordsOperation];
    }
}

- (void)removeDeletedEntitiesFromModelAdapters:(NSSet *)modelAdapters completion:(void(^)(NSError *error))completion
{
    if (modelAdapters.count == 0) {
        callBlockIfNotNil(completion, nil);
    } else {
        __weak QSCloudKitSynchronizer *weakSelf = self;
        id<QSModelAdapter> modelAdapter = [modelAdapters anyObject];
        [self removeDeletedEntitiesFromModelAdapter:modelAdapter completion:^(NSError *error) {
            if (error) {
                callBlockIfNotNil(completion, error);
            } else {
                NSMutableSet *pendingModelAdapters = [modelAdapters mutableCopy];
                [pendingModelAdapters removeObject:modelAdapter];
                [weakSelf removeDeletedEntitiesFromModelAdapters:pendingModelAdapters completion:completion];
            }
        }];
    }
}

- (void)removeDeletedEntitiesFromModelAdapter:(id<QSModelAdapter>)modelAdapter completion:(void(^)(NSError *error))completion
{
    NSArray *recordIDs = [modelAdapter recordIDsMarkedForDeletionWithLimit:self.batchSize];
    NSInteger recordCount = recordIDs.count;
    
    if (recordCount == 0) {
        callBlockIfNotNil(completion, nil);
    } else {
        //Now perform the operation
        CKModifyRecordsOperation *modifyRecordsOperation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:nil recordIDsToDelete:recordIDs];
        modifyRecordsOperation.modifyRecordsCompletionBlock = ^(NSArray <CKRecord *> *savedRecords, NSArray <CKRecordID *> *deletedRecordIDs, NSError *operationError) {
            dispatch_async(self.dispatchQueue, ^{
                DLog(@"QSCloudKitSynchronizer >> Deleted %ld records", (unsigned long)deletedRecordIDs.count);
                
                if (operationError.code == CKErrorLimitExceeded) {
                    self.batchSize = self.batchSize / 2;
                } else if (self.batchSize < self.maxBatchSize) {
                    self.batchSize += 5;
                }
                
                [modelAdapter didDeleteRecordIDs:deletedRecordIDs];
                
                callBlockIfNotNil(completion,operationError);
            });
        };
        
        self.currentOperation = modifyRecordsOperation;
        [self.database addOperation:modifyRecordsOperation];
    }
}

#pragma mark - 4) Update tokens

- (void)synchronizationUpdateServerTokens
{
    void (^completionBlock)(CKServerChangeToken * _Nullable, NSArray<CKRecordZoneID *> * _Nonnull, NSArray<CKRecordZoneID *> * _Nonnull) = ^(CKServerChangeToken * _Nullable databaseToken, NSArray<CKRecordZoneID *> * _Nonnull changedZoneIDs, NSArray<CKRecordZoneID *> * _Nonnull deletedZoneIDs) {
        
        [self notifyProviderForDeletedZoneIDs:deletedZoneIDs];
        if (changedZoneIDs.count) {
            [self updateServerTokenForRecordZones:changedZoneIDs withCompletion:^(BOOL needToFetchFullChanges) {
                
                if (needToFetchFullChanges) {
                    //There were changes before we finished, repeat process again
                    [self performSynchronization];
                } else {
                    self.serverChangeToken = databaseToken;
                    [self finishSynchronizationWithError:nil];
                }
            }];
        } else {
            [self finishSynchronizationWithError:nil];
        }
    };
    
    QSFetchDatabaseChangesOperation *operation = [[QSFetchDatabaseChangesOperation alloc] initWithDatabase:self.database
                                                                                             databaseToken:self.serverChangeToken
                                                                                                completion:completionBlock];
    
    [self runOperation:operation];
}

- (void)updateServerTokenForRecordZones:(NSArray<CKRecordZoneID *> *)zoneIDs withCompletion:(void(^)(BOOL needToFetchFullChanges))completion
{
    void(^completionBlock)(NSDictionary<CKRecordZoneID *,QSFetchZoneChangesOperationZoneResult *> * _Nonnull) = ^(NSDictionary<CKRecordZoneID *,QSFetchZoneChangesOperationZoneResult *> * _Nonnull zoneResults) {
        dispatch_async(self.dispatchQueue, ^{
            NSMutableArray *pendingZones = [NSMutableArray array];
            __block BOOL needsToRefetch = NO;
            [zoneResults enumerateKeysAndObjectsUsingBlock:^(CKRecordZoneID * _Nonnull zoneID, QSFetchZoneChangesOperationZoneResult * _Nonnull result, BOOL * _Nonnull stop) {
               
                id<QSModelAdapter> modelAdapter = self.modelAdapterDictionary[zoneID];
                if (result.downloadedRecords.count || result.deletedRecordIDs.count) {
                    needsToRefetch = YES;
                } else {
                    [modelAdapter saveToken:result.serverChangeToken];
                }
                if (result.moreComing) {
                    [pendingZones addObject:zoneID];
                }
            }];
            
            if (pendingZones.count && !needsToRefetch) {
                [self updateServerTokenForRecordZones:pendingZones withCompletion:completion];
            } else {
                callBlockIfNotNil(completion, needsToRefetch);
            }
        });
    };
    
    QSFetchZoneChangesOperation *operation = [[QSFetchZoneChangesOperation alloc] initWithDatabase:self.database
                                                                                           zoneIDs:zoneIDs
                                                                                  zoneChangeTokens:[self.activeZoneTokens copy]
                                                                                      modelVersion:self.compatibilityVersion
                                                                            ignoreDeviceIdentifier:self.deviceIdentifier
                                                                                       desiredKeys:@[@"recordID", QSCloudKitDeviceUUIDKey]
                                                                                        completion:completionBlock];
    
    [self runOperation:operation];
}

#pragma mark - 5) Finish

- (void)finishSynchronizationWithError:(NSError *)error
{
    self.syncing = NO;
    self.cancelSync = NO;
    
    [self resetActiveTokens];
    
    for (id<QSModelAdapter> modelAdapter in self.modelAdapters) {
        [modelAdapter didFinishImportWithError:error];
    }
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

#pragma mark - Utilities

@synthesize serverChangeToken = _serverChangeToken;

- (CKServerChangeToken *)serverChangeToken
{
    if (!_serverChangeToken) {
        _serverChangeToken = [self getStoredDatabaseToken];
    }
    return _serverChangeToken;
}

- (void)setServerChangeToken:(CKServerChangeToken *)serverChangeToken
{
    _serverChangeToken = serverChangeToken;
    [self storeDatabaseToken:serverChangeToken];
}

- (NSError *)cancelError {
    return [NSError errorWithDomain:QSCloudKitSynchronizerErrorDomain code:QSCloudKitSynchronizerErrorCancelled userInfo:@{QSCloudKitSynchronizerErrorKey: @"Synchronization was canceled"}];
}

- (void)runOperation:(QSCloudKitSynchronizerOperation *)operation
{
    operation.errorHandler = ^(QSCloudKitSynchronizerOperation * _Nonnull operation, NSError * _Nonnull error) {
        [self finishSynchronizationWithError:error];
    };
    self.currentOperation = operation;
    [self.operationQueue addOperation:operation];
}

- (void)notifyProviderForDeletedZoneIDs:(NSArray<CKRecordZoneID *> *)zoneIDs
{
    for (CKRecordZoneID *zoneID in zoneIDs) {
        [self.adapterProvider cloudKitSynchronizer:self zoneWasDeletedWithZoneID:zoneID];
    }
}

- (BOOL)isLimitExceededError:(NSError *)error
{
    if (error.code == CKErrorPartialFailure) {
        NSDictionary *errorsByItemID = error.userInfo[CKPartialErrorsByItemIDKey];
        for (NSError *error in [errorsByItemID allValues]) {
            if (error.code == CKErrorLimitExceeded) {
                return YES;
            }
        }
    }
    
    return error.code == CKErrorLimitExceeded;
}

- (BOOL)isServerRecordChangedError:(NSError *)error
{
    if (error.code == CKErrorPartialFailure) {
        NSDictionary *errorsByItemID = error.userInfo[CKPartialErrorsByItemIDKey];
        for (NSError *error in [errorsByItemID allValues]) {
            if (error.code == CKErrorServerRecordChanged) {
                return YES;
            }
        }
    }
    
    return error.code == CKErrorServerRecordChanged;
}

#pragma mark - RecordZone setup

- (BOOL)needsZoneSetup:(id<QSModelAdapter>)modelAdapter
{
    return modelAdapter.serverChangeToken == nil;
}

- (void)setupRecordZoneIfNeeded:(id<QSModelAdapter>)modelAdapter completion:(void(^)(NSError *error))completion
{
    if ([self needsZoneSetup:modelAdapter]) {
        [self setupRecordZone:modelAdapter.recordZoneID withCompletion:^(NSError *error) {
            callBlockIfNotNil(completion, error);
        }];
    } else {
        completion(nil);
    }
}

- (void)setupRecordZone:(CKRecordZoneID *)zoneID withCompletion:(void(^)(NSError *error))completionBlock
{
    [self.database fetchRecordZoneWithID:zoneID completionHandler:^(CKRecordZone * _Nullable zone, NSError * _Nullable error) {
        
        if (zone) {
            callBlockIfNotNil(completionBlock, error);
        } else if (error.code  == CKErrorZoneNotFound || error.code == CKErrorUserDeletedZone) {
            
            CKRecordZone *newZone = [[CKRecordZone alloc] initWithZoneID:zoneID];
            [self.database saveRecordZone:newZone completionHandler:^(CKRecordZone * _Nullable zone, NSError * _Nullable error) {
                if (!error && zone) {
                    DLog(@"QSCloudKitSynchronizer >> Created custom record zone: %@", zone);
                }
                callBlockIfNotNil(completionBlock, error);
            }];
            
        } else {
            callBlockIfNotNil(completionBlock, error);
        }
        
    }];
}

@end
