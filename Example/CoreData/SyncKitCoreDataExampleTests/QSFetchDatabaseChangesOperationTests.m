//
//  QSFetchDatabaseChangesOperationTests.m
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 15/06/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QSMockDatabase.h"
@import SyncKit;

@interface QSFetchDatabaseChangesOperationTests : XCTestCase

@property (nonatomic, strong) QSMockDatabase *mockDatabase;

@end

@implementation QSFetchDatabaseChangesOperationTests

- (void)setUp {
    [super setUp];
    
    self.mockDatabase = [[QSMockDatabase alloc] init];
}

- (void)tearDown {
    
    self.mockDatabase = nil;
    [super tearDown];
}

- (void)testOperation_returnsChangedZoneIDs
{
    NSArray<CKRecordZoneID *> *changedZoneIDs = @[[[CKRecordZoneID alloc] initWithZoneName:@"name1" ownerName:@"owner1"],
                                [[CKRecordZoneID alloc] initWithZoneName:@"name2" ownerName:@"owner2"]];
    __block NSMutableArray<CKRecordZoneID *> *downloadedChanged = [NSMutableArray array];
    
    self.mockDatabase.readyToFetchRecordZones = changedZoneIDs;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"finished"];
    QSFetchDatabaseChangesOperation *operation = [[QSFetchDatabaseChangesOperation alloc] initWithDatabase:(CKDatabase *)self.mockDatabase databaseToken:nil completion:^(CKServerChangeToken * _Nullable token, NSArray<CKRecordZoneID *> * _Nonnull downloaded, NSArray<CKRecordZoneID *> * _Nonnull deleted) {
        
        [downloadedChanged addObjectsFromArray:downloaded];
        [expectation fulfill];
    }];
    
    [operation start];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([changedZoneIDs isEqualToArray:downloadedChanged]);
}

- (void)testOperation_returnsDeletedZoneIDs
{
    NSArray<CKRecordZoneID *> *deletedZoneIDs = @[[[CKRecordZoneID alloc] initWithZoneName:@"name1" ownerName:@"owner1"],
                                                  [[CKRecordZoneID alloc] initWithZoneName:@"name2" ownerName:@"owner2"]];
    __block NSMutableArray<CKRecordZoneID *> *downloadedDeleted = [NSMutableArray array];
    
    self.mockDatabase.deletedRecordZoneIDs = deletedZoneIDs;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"finished"];
    QSFetchDatabaseChangesOperation *operation = [[QSFetchDatabaseChangesOperation alloc] initWithDatabase:(CKDatabase *)self.mockDatabase databaseToken:nil completion:^(CKServerChangeToken * _Nullable token, NSArray<CKRecordZoneID *> * _Nonnull downloaded, NSArray<CKRecordZoneID *> * _Nonnull deleted) {
        
        [downloadedDeleted addObjectsFromArray:deleted];
        [expectation fulfill];
    }];
    
    [operation start];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([deletedZoneIDs isEqualToArray:downloadedDeleted]);
}

- (void)testOperation_internalOperationReturnsError_returnsError
{
    NSArray<CKRecordZoneID *> *changedZoneIDs = @[[[CKRecordZoneID alloc] initWithZoneName:@"name1" ownerName:@"owner1"],
                                                  [[CKRecordZoneID alloc] initWithZoneName:@"name2" ownerName:@"owner2"]];
    __block NSMutableArray<CKRecordZoneID *> *downloadedChanged = [NSMutableArray array];
    
    self.mockDatabase.readyToFetchRecordZones = changedZoneIDs;
    NSError *opError = [NSError errorWithDomain:@"test" code:2 userInfo:nil];
    self.mockDatabase.fetchError = opError;
    __block NSError *error = nil;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"finished"];
    QSFetchDatabaseChangesOperation *operation = [[QSFetchDatabaseChangesOperation alloc] initWithDatabase:(CKDatabase *)self.mockDatabase databaseToken:nil completion:^(CKServerChangeToken * _Nullable token, NSArray<CKRecordZoneID *> * _Nonnull downloaded, NSArray<CKRecordZoneID *> * _Nonnull deleted) {
        
        [downloadedChanged addObjectsFromArray:downloaded];
    }];
    
    operation.errorHandler = ^(QSCloudKitSynchronizerOperation * _Nonnull operation, NSError * _Nonnull operationError) {
        
        error = operationError;
        [expectation fulfill];
    };
    
    [operation start];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqual(downloadedChanged.count, 0);
    XCTAssertEqual(error, opError);
}

@end
