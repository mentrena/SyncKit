//
//  QSCloudKitSynchronizerTests.m
//  QSCloudKitSynchronizer
//
//  Created by Manuel Entrena on 23/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import <XCTest/XCTest.h>
@import SyncKit;
#import <OCMock/OCMock.h>
#import <CloudKit/CloudKit.h>
#import "QSMockModelAdapter.h"
#import "QSMockDatabase.h"
#import "QSObject.h"
#import "QSMockKeyValueStore.h"
#import "QSMockAdapterProvider.h"
#import "QSMockManagedObjectContext.h"

@interface QSCloudKitSynchronizerTests : XCTestCase

@property (nonatomic, strong) QSCloudKitSynchronizer *synchronizer;
@property (nonatomic, strong) QSMockDatabase *mockDatabase;
@property (nonatomic, strong) QSMockModelAdapter *mockAdapter;
@property (nonatomic, strong) CKRecordZoneID *recordZoneID;
@property (nonatomic, strong) id mockContainer;
@property (nonatomic, strong) QSMockKeyValueStore *mockKeyValueStore;
@property (nonatomic, strong) QSMockAdapterProvider *mockAdapterProvider;

@end

@implementation QSCloudKitSynchronizerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    self.mockKeyValueStore = [[QSMockKeyValueStore alloc] init];

    //Pass our custom database
    self.mockDatabase = [QSMockDatabase new];

    self.mockContainer = OCMClassMock([CKContainer class]);
    OCMStub([self.mockContainer privateCloudDatabase]).andReturn(self.mockDatabase);
    OCMStub([self.mockContainer containerWithIdentifier:[OCMArg any]]).andReturn(self.mockContainer);

    self.recordZoneID = [[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"];
    
    self.mockAdapter = [[QSMockModelAdapter alloc] init];
    self.mockAdapter.recordZoneIDValue = self.recordZoneID;
    
    self.mockAdapterProvider = [[QSMockAdapterProvider alloc] init];
    self.mockAdapterProvider.modelAdapterValue = self.mockAdapter;

    self.synchronizer = [[QSCloudKitSynchronizer alloc] initWithIdentifier:@"testID" containerIdentifier:@"any" database:[[CKContainer containerWithIdentifier:@"any"] privateCloudDatabase] adapterProvider:self.mockAdapterProvider keyValueStore:self.mockKeyValueStore];

    [self.synchronizer addModelAdapter:self.mockAdapter];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [self.mockKeyValueStore clear];
    self.synchronizer = nil;
    self.recordZoneID = nil;
    self.mockAdapter = nil;
    self.mockContainer = nil;
    self.mockDatabase = nil;
    self.mockKeyValueStore = nil;
    self.mockAdapterProvider = nil;
    
    [super tearDown];
}

- (void)clearAllUserDefaults
{
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.mockKeyValueStore clear];
}

- (CKSubscription *)subscription
{
    CKSubscription *subscription;
    subscription = [[CKRecordZoneSubscription alloc] initWithZoneID:self.recordZoneID];
    
    CKNotificationInfo *notificationInfo = [[CKNotificationInfo alloc] init];
    notificationInfo.shouldSendContentAvailable = YES;
    subscription.notificationInfo = notificationInfo;
    return subscription;
}

- (void)testSynchronize_twoObjectsToUpload_uploadsThem
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1], [[QSObject alloc] initWithIdentifier:@"2" number:@2]];
    self.mockAdapter.objects = objects;
    [self.mockAdapter markForUpload:objects];
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssert(self.mockDatabase.receivedRecords.count == 2);
}

- (void)testSynchronize_oneObjectToDelete_deletesObject
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1], [[QSObject alloc] initWithIdentifier:@"2" number:@2]];
    self.mockAdapter.objects = objects;
    [self.mockAdapter markForDeletion:@[[objects lastObject]]];
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssert(self.mockDatabase.deletedRecordIDs.count == 1);
    XCTAssert(self.mockAdapter.objects.count == 1);
}

- (void)testSynchronize_oneObjectToFetch_downloadsObject
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1], [[QSObject alloc] initWithIdentifier:@"2" number:@2]];
    self.mockAdapter.objects = objects;
    
    QSObject *object = [[QSObject alloc] initWithIdentifier:@"3" number:@3];
    
    self.mockDatabase.readyToFetchRecords = @[[object recordWithZoneID:self.recordZoneID]];
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssert(self.mockAdapter.objects.count == 3);
}

- (void)testSynchronize_objectsToUploadAndDeleteAndFetch_UpdatesAll
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1],
                         [[QSObject alloc] initWithIdentifier:@"2" number:@2],
                         [[QSObject alloc] initWithIdentifier:@"3" number:@3],
                         [[QSObject alloc] initWithIdentifier:@"4" number:@4]];
    self.mockAdapter.objects = objects;
    [self.mockAdapter markForUpload:@[[objects objectAtIndex:0]]];
    [self.mockAdapter markForDeletion:@[[objects lastObject]]];
    
    QSObject *object = [[QSObject alloc] initWithIdentifier:@"5" number:@5];
    
    self.mockDatabase.readyToFetchRecords = @[[object recordWithZoneID:self.recordZoneID]];
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssert(self.mockDatabase.deletedRecordIDs.count == 1);
    XCTAssert(self.mockDatabase.receivedRecords.count == 1);
    XCTAssert(self.mockAdapter.objects.count == 4);
    QSObject *fifthObject = nil;
    for (QSObject *obj in self.mockAdapter.objects) {
        if ([obj.identifier isEqualToString:@"5"]) {
            fifthObject = obj;
        }
    }
    XCTAssertNotNil(fifthObject);
}

- (void)testSynchronize_errorInFetch_endsWithError
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];

    NSError *error = [NSError errorWithDomain:@"error" code:0 userInfo:nil];
    self.mockDatabase.fetchError = error;

    __block NSError *receivedError = nil;

    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        receivedError = error;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertEqualObjects(error, receivedError);
}

- (void)testSynchronize_errorInUpload_endsWithError
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    
    NSError *error = [NSError errorWithDomain:@"error" code:0 userInfo:nil];
    self.mockDatabase.uploadError = error;
    
    QSObject *object = [[QSObject alloc] initWithIdentifier:@"1" number:@1];
    self.mockAdapter.objects = @[object];
    [self.mockAdapter markForUpload:@[object]];
    
    __block NSError *receivedError = nil;
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        receivedError = error;
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqualObjects(error, receivedError);
}

- (void)testSynchronize_recordZoneNotCreated_createsRecordZone
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1], [[QSObject alloc] initWithIdentifier:@"2" number:@2]];
    
    self.mockAdapter.objects = objects;
    [self.mockAdapter markForUpload:objects];
    
    self.mockDatabase.fetchRecordZoneError = [NSError errorWithDomain:CKErrorDomain code:CKErrorZoneNotFound userInfo:nil];
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(self.mockDatabase.savedRecordZone);
}

- (void)testSynchronize_recordZoneHadBeenCreated_failsInUpload
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1], [[QSObject alloc] initWithIdentifier:@"2" number:@2]];
    
    self.mockAdapter.objects = objects;
    [self.mockAdapter markForUpload:objects];
    [self.mockAdapter saveToken:(CKServerChangeToken *)[NSString stringWithFormat:@"token"]];
    
    self.mockDatabase.uploadError = [NSError errorWithDomain:CKErrorDomain code:CKErrorZoneNotFound userInfo:nil];
    
    __block NSError *receivedError;
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        receivedError = error;
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(self.mockDatabase.savedRecordZone);
    XCTAssertEqual(receivedError.code, CKErrorZoneNotFound);
}

- (void)testSynchronize_limitExceededError_decreasesBatchSizeAndEndsWithError
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    
    NSInteger batchSize = self.synchronizer.batchSize;
    NSError *error = [NSError errorWithDomain:@"error"
                                         code:CKErrorLimitExceeded
                                     userInfo:nil];
    self.mockDatabase.uploadError = error;
    
    QSObject *object = [[QSObject alloc] initWithIdentifier:@"1" number:@1];
    self.mockAdapter.objects = @[object];
    [self.mockAdapter markForUpload:@[object]];
    
    __block NSError *receivedError = nil;
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        receivedError = error;
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSInteger halfBatchSize = self.synchronizer.batchSize;
    
    XCTAssertEqualObjects(error, receivedError);
    XCTAssertEqual(halfBatchSize, batchSize / 2);
    
    
    /*
     Synchronize without error increases batch size
     */
    
    self.mockDatabase.uploadError = nil;
    self.mockAdapter.objects = @[object];
    [self.mockAdapter markForUpload:@[object]];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Sync finished"];
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        receivedError = error;
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(receivedError);
    XCTAssertTrue(self.synchronizer.batchSize > halfBatchSize);
}

- (void)testSynchronize_limitExceededErrorInPartialError_decreasesBatchSizeAndEndsWithError
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    
    NSInteger batchSize = self.synchronizer.batchSize;
    NSError *error = [NSError errorWithDomain:@"error"
                                         code:CKErrorPartialFailure
                                     userInfo:@{CKPartialErrorsByItemIDKey: @{@"itemID": [NSError errorWithDomain:@"error"
                                                                                                       code:CKErrorLimitExceeded
                                                                                                   userInfo:nil]}
                                                
                                                }
                      ];
    self.mockDatabase.uploadError = error;
    
    QSObject *object = [[QSObject alloc] initWithIdentifier:@"1" number:@1];
    self.mockAdapter.objects = @[object];
    [self.mockAdapter markForUpload:@[object]];
    
    __block NSError *receivedError = nil;
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        receivedError = error;
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqualObjects(error, receivedError);
    XCTAssertEqual(self.synchronizer.batchSize, batchSize / 2);
}

- (void)testSynchronize_moreThanBatchSizeItems_performsMultipleUploads
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    
    NSMutableArray *objects = [NSMutableArray array];
    for (NSInteger i = 0; i < self.synchronizer.batchSize + 10; i++) {
        QSObject *object = [[QSObject alloc] initWithIdentifier:[NSString stringWithFormat:@"%ld", (long)i] number:@(i)];
        [objects addObject:object];
    }
    
    self.mockAdapter.objects = objects;
    [self.mockAdapter markForUpload:objects];
    
    __block NSInteger operationCount = 0;
    self.mockDatabase.modifyRecordsOperationEnqueuedBlock = ^(CKModifyRecordsOperation *operation) {
        operationCount++;
    };
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue(operationCount > 1);
}

- (void)testSynchronize_storesServerTokenAfterFetch
{
    //Make sure no token is carried over from another test
//    [self.synchronizer eraseLocalMetadata];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1], [[QSObject alloc] initWithIdentifier:@"2" number:@2]];
    self.mockAdapter.objects = objects;
    [self.mockAdapter markForUpload:objects];
    [self.mockAdapter saveToken:nil];
    
    XCTAssertNil(self.mockAdapter.serverChangeToken);
    
    __weak QSCloudKitSynchronizerTests *weakSelf = self;
    
    self.mockDatabase.modifyRecordsOperationEnqueuedBlock = ^(CKModifyRecordsOperation * _Nonnull operation) {
        weakSelf.mockDatabase.readyToFetchRecords = operation.recordsToSave;
    };
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertNotNil(self.mockAdapter.serverChangeToken);
}

- (void)testEraseLocal_deletesAdapterTracking
{
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1], [[QSObject alloc] initWithIdentifier:@"2" number:@2]];
    self.mockAdapter.objects = objects;
    
    [self.synchronizer eraseLocalMetadata];
    
    XCTAssert(self.mockAdapter.objects.count == 0);
    XCTAssertTrue(self.mockAdapter.deleteChangeTrackingCalled);
}

- (void)testEraseRemote_deletesRecordZone
{
    __block BOOL called = NO;
    self.mockDatabase.deleteRecordZoneCalledBlock = ^(CKRecordZoneID *zoneID) {
        called = YES;
    };
    
    [self.synchronizer deleteRecordZoneForModelAdapter:self.mockAdapter withCompletion:^(NSError *error) {
        
    }];
    
    XCTAssert(called == YES);
}

- (void)testSubscribeForRecordZoneNotifications_savesToDatabase
{
    [self clearAllUserDefaults];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Save subscription called"];
    
    __block BOOL called = NO;
    
    self.mockDatabase.subscriptionIDReturnValue = @"123";
    self.mockDatabase.saveSubscriptionCalledBlock = ^(CKSubscription *subscription) {
        called = YES;
    };
    
    [self.synchronizer subscribeForChangesIn:self.recordZoneID completion:^(NSError * _Nullable error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSString *subscriptionID = [self.synchronizer subscriptionIDForRecordZoneID:self.recordZoneID];

    XCTAssertTrue(called);
    XCTAssertEqual(subscriptionID, @"123");
}

- (void)testSubscribeForDatabaseNotifications_savesToDatabase
{
    [self clearAllUserDefaults];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Save subscription called"];
    
    __block BOOL called = NO;
    
    self.mockDatabase.scope = CKDatabaseScopeShared;
    self.mockDatabase.subscriptionIDReturnValue = @"456";
    self.mockDatabase.saveSubscriptionCalledBlock = ^(CKSubscription *subscription) {
        called = YES;
    };
    
    [self.synchronizer subscribeForChangesInDatabaseWithCompletion:^(NSError * _Nullable error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    NSString *subscriptionID = [self.synchronizer subscriptionIDForDatabaseSubscription];
    
    XCTAssertTrue(called);
    XCTAssertEqual(subscriptionID, @"456");
}

- (void)testSubscribeForUpdateNotifications_existingSubscription_updatesSubscriptionID
{
    [self clearAllUserDefaults];
    
    CKSubscription *subscription = [self subscription];
    self.mockDatabase.subscriptions = @[subscription];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Fetched subscriptions"];
    
    self.mockDatabase.fetchAllSubscriptionsCalledBlock = ^ {
        [expectation fulfill];
    };
    
    __block BOOL saveCalled = NO;
    self.mockDatabase.saveSubscriptionCalledBlock = ^(CKSubscription *subscription) {
        saveCalled = YES;
    };
    
    [self.synchronizer subscribeForChangesIn:self.recordZoneID completion:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertFalse(saveCalled);
    XCTAssertEqual([self.synchronizer subscriptionIDForRecordZoneID:self.recordZoneID], subscription.subscriptionID);
}

- (void)testDeleteSubscription_deletesOnDatabase
{
    
    XCTestExpectation *saved = [self expectationWithDescription:@"saved"];
    [self.synchronizer subscribeForChangesIn:self.recordZoneID completion:^(NSError *error) {
        [saved fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    
    XCTestExpectation *deleted = [self expectationWithDescription:@"Save subscription called"];
    __block BOOL called = NO;
    
    self.mockDatabase.deleteSubscriptionCalledBlock = ^(NSString *subscriptionID) {
        called = YES;
    };
    
    [self.synchronizer cancelSubscriptionForChangesIn:self.recordZoneID completion:^(NSError * _Nullable error) {
        [deleted fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSString *subscriptionID = [self.synchronizer subscriptionIDForRecordZoneID:self.recordZoneID];
    
    XCTAssertTrue(called);
    XCTAssertNil(subscriptionID);
}

- (void)testDeleteSubscription_noLocalSubscriptionButRemoteOne_deletesOnDatabase
{
    [self clearAllUserDefaults];
    
    CKSubscription *subscription = [self subscription];
    self.mockDatabase.subscriptions = @[subscription];
    
    XCTestExpectation *deleted = [self expectationWithDescription:@"Save subscription called"];
    
    __block NSString *deletedSubscriptionID = nil;
    self.mockDatabase.deleteSubscriptionCalledBlock = ^(NSString *subscriptionID) {
        deletedSubscriptionID = subscriptionID;
        [deleted fulfill];
    };
    
    [self.synchronizer cancelSubscriptionForChangesIn:self.recordZoneID completion:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqual(deletedSubscriptionID, subscription.subscriptionID);
}

- (void)testSynchronize_objectChanges_callsAllAdapterMethods
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1],
                         [[QSObject alloc] initWithIdentifier:@"2" number:@2],
                         [[QSObject alloc] initWithIdentifier:@"3" number:@3]];
    self.mockAdapter.objects = objects;
    [self.mockAdapter markForUpload:@[[objects objectAtIndex:1]]];
    [self.mockAdapter markForDeletion:@[[objects objectAtIndex:2]]];
    
    QSObject *object = [[QSObject alloc] initWithIdentifier:@"4" number:@4];
    
    self.mockDatabase.readyToFetchRecords = @[[object recordWithZoneID:self.recordZoneID]];
    self.mockDatabase.toDeleteRecordIDs = @[[(QSObject *)[objects firstObject] recordIDWithZoneID:self.recordZoneID]];
    
    id mock = OCMPartialMock(self.mockAdapter);
    
    OCMExpect([mock prepareForImport]).andForwardToRealObject();
    OCMExpect([mock saveChangesInRecords:[OCMArg any]]).andForwardToRealObject();
    OCMExpect([mock deleteRecordsWithIDs:[OCMArg any]]).andForwardToRealObject();
    [[[[mock expect] ignoringNonObjectArgs] andForwardToRealObject] recordsToUploadWithLimit:1];
    OCMExpect([mock didUploadRecords:[OCMArg any]]).andForwardToRealObject();
    [[[[mock expect] ignoringNonObjectArgs] andForwardToRealObject] recordIDsMarkedForDeletionWithLimit:1];
    OCMExpect([mock didDeleteRecordIDs:[OCMArg any]]).andForwardToRealObject();
    OCMExpect([mock persistImportedChangesWithCompletion:[OCMArg any]]).andForwardToRealObject();
    OCMExpect([mock didFinishImportWithError:[OCMArg any]]).andForwardToRealObject();
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    OCMVerifyAll(mock);
    [mock stopMocking];
}

- (void)testSynchronize_newerModelVersion_cancelsSynchronizationWithError
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1],
                         [[QSObject alloc] initWithIdentifier:@"2" number:@2],
                         [[QSObject alloc] initWithIdentifier:@"3" number:@3]];
    self.mockAdapter.objects = objects;
    [self.mockAdapter markForUpload:objects];
    
    id mock = OCMPartialMock(self.mockAdapter);
    
    self.synchronizer.compatibilityVersion = 2;
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    QSCloudKitSynchronizer *synchronizer2 = [[QSCloudKitSynchronizer alloc] initWithIdentifier:@"testID2" containerIdentifier:@"any" database:[[CKContainer containerWithIdentifier:@"any"] privateCloudDatabase] adapterProvider:self.mockAdapterProvider keyValueStore:self.mockKeyValueStore];
    
    self.mockDatabase.readyToFetchRecords = self.mockDatabase.receivedRecords;
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Sync finished"];
    
    //Now update compatibility version and fetch records
    synchronizer2.compatibilityVersion = 1;
    __block NSError *syncError = nil;
    
    [synchronizer2 synchronizeWithCompletion:^(NSError *error) {
        syncError = error;
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertTrue([syncError.domain isEqualToString:QSCloudKitSynchronizerErrorDomain]);
    XCTAssertTrue(syncError.code == QSCloudKitSynchronizerErrorHigherModelVersionFound);
    
    [mock stopMocking];
}

- (void)testSynchronize_usesModelVersion_synchronizesWithPreviousVersions
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1],
                         [[QSObject alloc] initWithIdentifier:@"2" number:@2],
                         [[QSObject alloc] initWithIdentifier:@"3" number:@3]];
    self.mockAdapter.objects = objects;
    [self.mockAdapter markForUpload:objects];
    
    id mock = OCMPartialMock(self.mockAdapter);
    
    self.synchronizer.compatibilityVersion = 1;
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    self.mockDatabase.readyToFetchRecords = self.mockDatabase.receivedRecords;
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Sync finished"];
    
    //Now update compatibility version and fetch records
    self.synchronizer.compatibilityVersion = 2;
    __block NSError *syncError = nil;
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        syncError = error;
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertNil(syncError);
    
    [mock stopMocking];
}

- (void)testSynchronize_downloadOnly_doesNotUploadChanges
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1],
                         [[QSObject alloc] initWithIdentifier:@"2" number:@2],
                         [[QSObject alloc] initWithIdentifier:@"3" number:@3]];
    self.mockAdapter.objects = objects;
    [self.mockAdapter markForUpload:objects];
    
    QSObject *object1 = [[QSObject alloc] initWithIdentifier:@"4" number:@4];
    QSObject *object2 = [[QSObject alloc] initWithIdentifier:@"3" number:@5];
    
    self.mockDatabase.readyToFetchRecords = @[[object1 recordWithZoneID:self.recordZoneID], [object2 recordWithZoneID:self.recordZoneID]];
    
    self.synchronizer.syncMode = QSCloudKitSynchronizeModeDownload;
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    QSObject *updatedObject = nil;
    for (QSObject *object in self.mockAdapter.objects) {
        if ([object.identifier isEqualToString:@"3"]) {
            updatedObject = object;
            break;
        }
    }
    
    XCTAssertTrue(self.mockDatabase.receivedRecords.count == 0);
    XCTAssertTrue(self.mockAdapter.objects.count == 4);
    XCTAssertTrue([updatedObject.number isEqual:@5]);
}

- (void)testSynchronize_newRecordZone_callsAdapterProvider
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1], [[QSObject alloc] initWithIdentifier:@"2" number:@2]];
    self.mockAdapter.objects = objects;
    
    QSObject *object = [[QSObject alloc] initWithIdentifier:@"3" number:@3];
    
    self.mockDatabase.readyToFetchRecords = @[[object recordWithZoneID:self.recordZoneID]];
    
    [self.synchronizer removeModelAdapter:self.mockAdapter];
    
    XCTAssertTrue(self.synchronizer.modelAdapters.count == 0);
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue(self.mockAdapterProvider.modelAdapterForRecordZoneIDCalled);
    XCTAssertTrue(self.synchronizer.modelAdapters.count == 1);
}

- (void)testSynchronize_recordZoneWasDeleted_callsAdapterProvider
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Sync finished"];
    NSArray *objects = @[[[QSObject alloc] initWithIdentifier:@"1" number:@1], [[QSObject alloc] initWithIdentifier:@"2" number:@2]];
    self.mockAdapter.objects = objects;
    
    self.mockDatabase.deletedRecordZoneIDs = @[self.recordZoneID];
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue(self.mockAdapterProvider.zoneWasDeletedWithIDCalled);
}

@end
