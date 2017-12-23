//
//  QSMockDatabase.m
//  QSCloudKitSynchronizer
//
//  Created by Manuel Entrena on 24/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import "QSMockDatabase.h"
#import <OCMock/OCMock.h>

@interface QSMockDatabase ()

@property (nonatomic, assign) NSInteger tokenIndex;

@end

@implementation QSMockDatabase

- (NSString *)serverToken
{
    return [NSString stringWithFormat:@"token%ld", (long)self.tokenIndex];
}

- (NSArray *)receivedRecords
{
    if (!_receivedRecords) {
        _receivedRecords = [NSArray array];
    }
    return _receivedRecords;
}

- (NSArray *)deletedRecordIDs
{
    if (!_deletedRecordIDs) {
        _deletedRecordIDs = [NSArray array];
    }
    return _deletedRecordIDs;
}

- (void)addOperation:(CKDatabaseOperation *)operation
{
    if ([operation isKindOfClass:[CKFetchRecordZoneChangesOperation class]]) {
        [self handleFetchRecordZoneChangesOperation:(CKFetchRecordZoneChangesOperation *)operation];
    } else if ([operation isKindOfClass:[CKFetchRecordChangesOperation class]]) {
        [self handleFetchRecordChangesOperation:(CKFetchRecordChangesOperation *)operation];
    } else if ([operation isKindOfClass:[CKModifyRecordsOperation class]]) {
        [self handleModifyRecordsOperation:(CKModifyRecordsOperation *)operation];
    }
}

- (void)handleFetchRecordChangesOperation:(CKFetchRecordChangesOperation *)operation
{
    if (self.fetchRecordChangesOperationEnqueuedBlock) {
        self.fetchRecordChangesOperationEnqueuedBlock(operation);
    }
    for (CKRecord *record in self.readyToFetchRecords) {
        operation.recordChangedBlock(record);
    }
    for (CKRecordID *recordID in self.toDeleteRecordIDs) {
        operation.recordWithIDWasDeletedBlock(recordID);
    }
    
    id partialMock = OCMPartialMock(operation);
    OCMStub([partialMock moreComing]).andCall(self, @selector(moreComing));

    operation.fetchRecordChangesCompletionBlock((CKServerChangeToken *)[self serverToken],
                                                [NSData new],
                                                self.fetchError);
    
    self.readyToFetchRecords = nil;
    self.toDeleteRecordIDs = nil;
    self.fetchError = nil;
}

- (void)handleFetchRecordZoneChangesOperation:(CKFetchRecordZoneChangesOperation *)operation
{
    if (self.fetchRecordZoneChangesOperationEnqueuedBlock) {
        self.fetchRecordZoneChangesOperationEnqueuedBlock(operation);
    }
    for (CKRecord *record in self.readyToFetchRecords) {
        operation.recordChangedBlock(record);
    }
    for (CKRecordID *recordID in self.toDeleteRecordIDs) {
        operation.recordWithIDWasDeletedBlock(recordID, @"recordType");
    }
    
    operation.recordZoneFetchCompletionBlock(operation.recordZoneIDs.firstObject,
                                             (CKServerChangeToken *)[self serverToken],
                                             [NSData new],
                                             false,
                                             self.fetchError);
    
    self.readyToFetchRecords = nil;
    self.toDeleteRecordIDs = nil;
    self.fetchError = nil;
}

- (BOOL)moreComing
{
    return NO;
}

- (void)handleModifyRecordsOperation:(CKModifyRecordsOperation *)operation
{
    if (self.modifyRecordsOperationEnqueuedBlock) {
        self.modifyRecordsOperationEnqueuedBlock(operation);
    }
    
    self.receivedRecords = [self.receivedRecords arrayByAddingObjectsFromArray:operation.recordsToSave];
    self.deletedRecordIDs = [self.deletedRecordIDs arrayByAddingObjectsFromArray:operation.recordIDsToDelete];
    
    if (self.receivedRecords.count || self.deletedRecordIDs.count) {
        self.tokenIndex++;
    }
    
    operation.modifyRecordsCompletionBlock(operation.recordsToSave, operation.recordIDsToDelete, self.uploadError);
}

- (void)fetchRecordZoneWithID:(CKRecordZoneID *)zoneID completionHandler:(void (^)(CKRecordZone * _Nullable, NSError * _Nullable))completionHandler
{
    if (self.fetchRecordZoneError) {
        completionHandler(nil, self.fetchRecordZoneError);
    } else {
        CKRecordZone *zone = [[CKRecordZone alloc] initWithZoneID:zoneID];
        completionHandler(zone, nil);
    }
}

- (void)saveRecordZone:(CKRecordZone *)zone completionHandler:(void (^)(CKRecordZone * _Nullable, NSError * _Nullable))completionHandler
{
    completionHandler(zone, nil);
}

- (void)saveSubscription:(CKSubscription *)subscription completionHandler:(void (^)(CKSubscription * _Nullable, NSError * _Nullable))completionHandler
{
    if (self.saveSubscriptionCalledBlock) {
        self.saveSubscriptionCalledBlock(subscription);
    }
    id mockSubscription = OCMClassMock([CKSubscription class]);
    OCMStub([mockSubscription subscriptionID]).andReturn(@"subscriptionIdentifier");
    completionHandler(mockSubscription, nil);
}

- (void)deleteSubscriptionWithID:(NSString *)subscriptionID completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler
{
    if (self.deleteSubscriptionCalledBlock) {
        self.deleteSubscriptionCalledBlock(subscriptionID);
    }
    completionHandler(nil, nil);
}

- (void)fetchAllSubscriptionsWithCompletionHandler:(void (^)(NSArray<CKSubscription *> * _Nullable subscriptions, NSError * _Nullable error))completionHandler
{
    if (self.fetchAllSubscriptionsCalledBlock) {
        self.fetchAllSubscriptionsCalledBlock();
    }
    completionHandler(self.subscriptions, nil);
}

- (void)deleteRecordZoneWithID:(CKRecordZoneID *)zoneID completionHandler:(void (^)(CKRecordZoneID * _Nullable zoneID, NSError * _Nullable error))completionHandler
{
    if (self.deleteRecordZoneCalledBlock) {
        self.deleteRecordZoneCalledBlock(zoneID);
    }
    completionHandler(zoneID, nil);
}

@end
