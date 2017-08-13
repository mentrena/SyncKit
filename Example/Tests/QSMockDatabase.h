//
//  QSMockDatabase.h
//  QSCloudKitSynchronizer
//
//  Created by Manuel Entrena on 24/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import <CloudKit/CloudKit.h>

@interface QSMockDatabase : NSObject

@property (nonatomic, readonly) NSString *serverToken;

@property (nonatomic, strong) NSArray *receivedRecords;
@property (nonatomic, strong) NSArray *deletedRecordIDs;

@property (nonatomic, strong) NSArray *readyToFetchRecords;
@property (nonatomic, strong) NSArray *toDeleteRecordIDs;

@property (nonatomic, strong) NSError *fetchError;
@property (nonatomic, strong) NSError *uploadError;

@property (nonatomic, strong) NSArray *subscriptions;

@property (nonatomic, copy) void(^fetchRecordChangesOperationEnqueuedBlock)(CKFetchRecordChangesOperation *operation);
@property (nonatomic, copy) void(^modifyRecordsOperationEnqueuedBlock)(CKModifyRecordsOperation *operation);
@property (nonatomic, copy) void(^saveSubscriptionCalledBlock)(CKSubscription *subscription);
@property (nonatomic, copy) void(^deleteSubscriptionCalledBlock)(NSString *subscriptionID);
@property (nonatomic, copy) void(^deleteRecordZoneCalledBlock)(CKRecordZoneID *zoneID);
@property (nonatomic, copy) void (^fetchAllSubscriptionsCalledBlock)();

- (void)addOperation:(CKDatabaseOperation *)operation;
- (void)fetchRecordZoneWithID:(CKRecordZoneID *)zoneID completionHandler:(void (^)(CKRecordZone *, NSError *))completionHandler;
- (void)saveRecordZone:(CKRecordZone *)zone completionHandler:(void (^)(CKRecordZone *, NSError *))completionHandler;
- (void)saveSubscription:(CKSubscription *)subscription completionHandler:(void (^)(CKSubscription *, NSError *))completionHandler;
- (void)deleteSubscriptionWithID:(NSString *)subscriptionID completionHandler:(void (^)(NSString *, NSError *))completionHandler;
- (void)fetchAllSubscriptionsWithCompletionHandler:(void (^)(NSArray<CKSubscription *> * _Nullable subscriptions, NSError * _Nullable error))completionHandler;

@end
