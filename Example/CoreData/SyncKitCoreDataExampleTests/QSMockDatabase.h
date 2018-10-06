//
//  QSMockDatabase.h
//  QSCloudKitSynchronizer
//
//  Created by Manuel Entrena on 24/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import <CloudKit/CloudKit.h>

@interface QSMockDatabase : NSObject

@property (nonatomic, assign) CKDatabaseScope scope;
@property (nonatomic, readonly, nullable) NSString * serverToken;

@property (nonatomic, strong, nonnull) NSArray *receivedRecords;
@property (nonatomic, strong, nonnull) NSArray *deletedRecordIDs;


@property (nonatomic, strong, nullable) NSArray *readyToFetchRecordZones;
@property (nonatomic, strong, nullable) NSArray *deletedRecordZoneIDs;
@property (nonatomic, strong, nullable) NSArray *readyToFetchRecords;
@property (nonatomic, strong, nullable) NSArray *toDeleteRecordIDs;

@property (nonatomic, strong, nullable) NSError *fetchRecordZoneError;
@property (nonatomic, strong, nullable) NSError *fetchError;
@property (nonatomic, strong, nullable) NSError *uploadError;

@property (nonatomic, strong, nullable) CKRecordZone *savedRecordZone;

@property (nonatomic, strong, nullable) NSArray *subscriptions;

@property (nonatomic, strong, nullable) NSString *subscriptionIDReturnValue;

@property (nonatomic, copy, nullable) void(^fetchDatabaseChangesOperationEnqueuedBlock)(CKFetchDatabaseChangesOperation * _Nonnull operation);
@property (nonatomic, copy, nullable) void(^fetchRecordZoneChangesOperationEnqueuedBlock)(CKFetchRecordZoneChangesOperation * _Nonnull operation);
@property (nonatomic, copy, nullable) void(^modifyRecordsOperationEnqueuedBlock)(CKModifyRecordsOperation * _Nonnull operation);
@property (nonatomic, copy, nullable) void(^saveSubscriptionCalledBlock)(CKSubscription * _Nonnull subscription);
@property (nonatomic, copy, nullable) void(^deleteSubscriptionCalledBlock)(NSString * _Nonnull subscriptionID);
@property (nonatomic, copy, nullable) void(^deleteRecordZoneCalledBlock)(CKRecordZoneID * _Nonnull zoneID);
@property (nonatomic, copy, nullable) void (^fetchAllSubscriptionsCalledBlock)(void);

- (void)addOperation:(nonnull CKDatabaseOperation *)operation;
- (void)fetchRecordZoneWithID:(nonnull CKRecordZoneID *)zoneID completionHandler:(nonnull void (^)(CKRecordZone * _Nonnull, NSError * _Nullable))completionHandler;
- (void)saveRecordZone:(nonnull CKRecordZone *)zone completionHandler:(nonnull void (^)(CKRecordZone * _Nonnull, NSError * _Nullable))completionHandler;
- (void)saveSubscription:(nonnull CKSubscription *)subscription completionHandler:(nonnull void (^)(CKSubscription * _Nonnull, NSError * _Nullable))completionHandler;
- (void)deleteSubscriptionWithID:(nonnull NSString *)subscriptionID completionHandler:(nonnull void (^)(NSString * _Nonnull, NSError * _Nullable))completionHandler;
- (void)fetchAllSubscriptionsWithCompletionHandler:(nonnull void (^)(NSArray<CKSubscription *> * _Nullable subscriptions, NSError * _Nullable error))completionHandler;

@end
