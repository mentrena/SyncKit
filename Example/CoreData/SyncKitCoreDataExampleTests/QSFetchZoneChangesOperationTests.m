//
//  QSFetchZoneChangesOperationTests.m
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 15/06/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QSMockDatabase.h"
@import SyncKit;

@interface QSFetchZoneChangesOperationTests : XCTestCase

@property (nonatomic, strong) QSMockDatabase *mockDatabase;

@end

@implementation QSFetchZoneChangesOperationTests

- (void)setUp {
    [super setUp];
    
    self.mockDatabase = [[QSMockDatabase alloc] init];
}

- (void)tearDown {
    
    self.mockDatabase = nil;
    [super tearDown];
}

- (CKRecord *)recordWithName:(NSString *)recordName zoneID:(CKRecordZoneID *)zoneID
{
    CKRecord *record = [[CKRecord alloc] initWithRecordType:@"testType" recordID:[[CKRecordID alloc] initWithRecordName:recordName zoneID:zoneID]];
    return record;
}

- (void)testOperation_returnsChangedRecords
{
    CKRecordZoneID *zoneID = [[CKRecordZoneID alloc] initWithZoneName:@"zoneName" ownerName:@"ownerName"];
    CKRecordZoneID *zoneID2 = [[CKRecordZoneID alloc] initWithZoneName:@"zoneName2" ownerName:@"ownerName2"];
    NSArray<CKRecord *> *changedRecords = @[[self recordWithName:@"record1" zoneID:zoneID],
                                            [self recordWithName:@"record2" zoneID:zoneID],
                                            [self recordWithName:@"record1" zoneID:zoneID2],
                                            [self recordWithName:@"record2" zoneID:zoneID2]];
    
    
    self.mockDatabase.readyToFetchRecords = changedRecords;
    
    NSMutableArray *downloadedRecords = [NSMutableArray array];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"finished"];
    QSFetchZoneChangesOperation *operation = [[QSFetchZoneChangesOperation alloc] initWithDatabase:(CKDatabase *)self.mockDatabase zoneIDs:@[zoneID, zoneID2] zoneChangeTokens:@{} modelVersion:0 ignoreDeviceIdentifier:@"" desiredKeys:nil completion:^(NSDictionary<CKRecordZoneID *,QSFetchZoneChangesOperationZoneResult *> * _Nonnull zoneResults) {
        
        QSFetchZoneChangesOperationZoneResult *zoneResult = zoneResults[zoneID];
        [downloadedRecords addObjectsFromArray:zoneResult.downloadedRecords];
        
        QSFetchZoneChangesOperationZoneResult *zoneResult2 = zoneResults[zoneID2];
        [downloadedRecords addObjectsFromArray:zoneResult2.downloadedRecords];
        
        [expectation fulfill];
    }];
    
    [operation start];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([downloadedRecords isEqualToArray:changedRecords]);
}

- (void)testOperation_returnsDeletedRecordIDs
{
    CKRecordZoneID *zoneID = [[CKRecordZoneID alloc] initWithZoneName:@"zoneName" ownerName:@"ownerName"];
    CKRecordZoneID *zoneID2 = [[CKRecordZoneID alloc] initWithZoneName:@"zoneName2" ownerName:@"ownerName2"];
    NSArray<CKRecordID *> *deletedRecordIDs = @[[[CKRecordID alloc] initWithRecordName:@"record1" zoneID:zoneID],
                                                [[CKRecordID alloc] initWithRecordName:@"record2" zoneID:zoneID],
                                                [[CKRecordID alloc] initWithRecordName:@"record1" zoneID:zoneID2],
                                                [[CKRecordID alloc] initWithRecordName:@"record2" zoneID:zoneID2]];
    
    
    self.mockDatabase.toDeleteRecordIDs = deletedRecordIDs;
    
    NSMutableArray *downloadedRecords = [NSMutableArray array];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"finished"];
    QSFetchZoneChangesOperation *operation = [[QSFetchZoneChangesOperation alloc] initWithDatabase:(CKDatabase *)self.mockDatabase zoneIDs:@[zoneID, zoneID2] zoneChangeTokens:@{} modelVersion:0 ignoreDeviceIdentifier:@"" desiredKeys:nil completion:^(NSDictionary<CKRecordZoneID *,QSFetchZoneChangesOperationZoneResult *> * _Nonnull zoneResults) {
        
        QSFetchZoneChangesOperationZoneResult *zoneResult = zoneResults[zoneID];
        [downloadedRecords addObjectsFromArray:zoneResult.deletedRecordIDs];
        
        QSFetchZoneChangesOperationZoneResult *zoneResult2 = zoneResults[zoneID2];
        [downloadedRecords addObjectsFromArray:zoneResult2.deletedRecordIDs];
        
        [expectation fulfill];
    }];
    
    [operation start];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([downloadedRecords isEqualToArray:deletedRecordIDs]);
}

- (void)testOperation_internalOperationReturnsError_returnsError
{
    CKRecordZoneID *zoneID = [[CKRecordZoneID alloc] initWithZoneName:@"zoneName" ownerName:@"ownerName"];
    
    NSArray<CKRecord *> *changedRecords = @[[self recordWithName:@"record1" zoneID:zoneID],
                                            [self recordWithName:@"record2" zoneID:zoneID]];
    
    
    self.mockDatabase.readyToFetchRecords = changedRecords;
    NSError *operationError = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
    self.mockDatabase.fetchError = operationError;
    
    NSMutableArray *downloadedRecords = [NSMutableArray array];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"finished"];
    QSFetchZoneChangesOperation *operation = [[QSFetchZoneChangesOperation alloc] initWithDatabase:(CKDatabase *)self.mockDatabase zoneIDs:@[zoneID] zoneChangeTokens:@{} modelVersion:0 ignoreDeviceIdentifier:@"" desiredKeys:nil completion:^(NSDictionary<CKRecordZoneID *,QSFetchZoneChangesOperationZoneResult *> * _Nonnull zoneResults) {
        
        QSFetchZoneChangesOperationZoneResult *zoneResult = zoneResults[zoneID];
        [downloadedRecords addObjectsFromArray:zoneResult.downloadedRecords];
        
        
    }];
    
    __block NSError *receivedError = nil;
    operation.errorHandler = ^(QSCloudKitSynchronizerOperation * _Nonnull operation, NSError * _Nonnull error) {
        receivedError = error;
        [expectation fulfill];
    };
    
    [operation start];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqual(downloadedRecords.count, 0);
    XCTAssertEqual(receivedError, operationError);
}


@end
