//
//  QSCoreDataChangeManagerTests.m
//  SyncKit
//
//  Created by Manuel Entrena on 26/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <SyncKit/QSCoreDataChangeManager.h>
#import <SyncKit/QSCoreDataStack.h>
#import <SyncKit/NSManagedObjectContext+QSFetch.h>
#import "QSEmployee.h"
#import "QSCompany.h"

@interface QSCoreDataChangeManagerTests : XCTestCase <QSCoreDataChangeManagerDelegate>

@property (nonatomic, strong) QSCoreDataStack *targetCoreDataStack;
@property (nonatomic, strong) QSCoreDataStack *coreDataStack;
@property (nonatomic, strong) QSCoreDataChangeManager *changeManager;

@property (nonatomic, assign) BOOL didCallRequestContextSave;
@property (nonatomic, assign) BOOL didCallImportChanges;

@end

@implementation QSCoreDataChangeManagerTests

- (void)setUp {
    [super setUp];
    
    NSURL *modelURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"QSExample" withExtension:@"momd"];
    self.targetCoreDataStack = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL] storePath:nil dispatchImmediately:YES];
    self.coreDataStack = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataChangeManager persistenceModel] storePath:nil dispatchImmediately:YES];
}

- (void)changeManagerRequestsContextSave:(QSCoreDataChangeManager *)changeManager completion:(void(^)(NSError *))completion
{
    self.didCallRequestContextSave = YES;
    [self.targetCoreDataStack.managedObjectContext performBlockAndWait:^{
        [self.targetCoreDataStack.managedObjectContext save:nil];
    }];
    completion(nil);
}

- (void)changeManager:(QSCoreDataChangeManager *)changeManager didImportChanges:(NSManagedObjectContext *)importContext completion:(void(^)(NSError *error))completion
{
    self.didCallImportChanges = YES;
    [importContext performBlockAndWait:^{
        [importContext save:nil];
        [self.targetCoreDataStack.managedObjectContext performBlockAndWait:^{
            [self.targetCoreDataStack.managedObjectContext save:nil];
        }];
        completion(nil);
    }];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testPersistImportedChanges_callsDelegate
{
    self.didCallRequestContextSave = NO;
    self.didCallImportChanges = NO;
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertTrue(self.didCallImportChanges);
    XCTAssertTrue(self.didCallRequestContextSave);
}

- (void)testRecordsToUploadWithLimit_initialSync_returnsRecord
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"new name";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordsToUploadWithLimit:10];
    [changeManager didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count > 0);
    CKRecord *record = [records firstObject];
    XCTAssertTrue([record[@"name"] isEqual:@"new name"]);
}

- (void)testRecordsToUpload_changedObject_returnsRecordWithChanges
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now change object
    company.name = @"name 2";
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    //Try to sync again
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordsToUploadWithLimit:10];
    [changeManager didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count > 0);
    CKRecord *record = [records firstObject];
    XCTAssertTrue([record[@"name"] isEqual:@"name 2"]);
}

- (void)testRecordsMarkedForDeletion_deletedObject_returnsRecordID
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now delete object
    [self.targetCoreDataStack.managedObjectContext performBlockAndWait:^{
        [self.targetCoreDataStack.managedObjectContext deleteObject:company];
        [self.targetCoreDataStack.managedObjectContext save:nil];
    }];
    
    //Try to sync again
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordIDsMarkedForDeletionWithLimit:1000];
    [changeManager didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count > 0);
}
- (void)testDeleteRecordWithID_deletesCorrespondingObject
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    company = nil;
    
    //Start sync and delete object
    [changeManager prepareForImport];
    [changeManager deleteRecordWithID:objectRecord.recordID];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSArray *objects = [self.targetCoreDataStack.managedObjectContext executeFetchRequestWithEntityName:@"QSCompany" error:nil];
    XCTAssertTrue(objects.count == 0);
}

- (void)testSaveChangesInRecord_existingObject_updatesObject
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    objectRecord[@"name"] = @"name 2";
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [changeManager prepareForImport];
    [changeManager saveChangesInRecord:objectRecord];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [self.targetCoreDataStack.managedObjectContext refreshObject:company mergeChanges:NO];
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
}

- (void)testSaveChangesInRecord_newObject_insertsObject
{
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    CKRecord *objectRecord = [[CKRecord alloc] initWithRecordType:@"QSCompany" recordID:[[CKRecordID alloc] initWithRecordName:@"QSCompany"]];
    objectRecord[@"name"] = @"new company";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [changeManager prepareForImport];
    [changeManager saveChangesInRecord:objectRecord];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSArray *objects = [self.targetCoreDataStack.managedObjectContext executeFetchRequestWithEntityName:@"QSCompany" error:nil];
    XCTAssertTrue(objects.count == 1);
    QSCompany *company = [objects firstObject];
    XCTAssertTrue([company.name isEqualToString:@"new company"]);
}

- (void)testSync_multipleObjects_preservesRelationships
{
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    CKRecord *companyRecord = [[CKRecord alloc] initWithRecordType:@"QSCompany" recordID:[[CKRecordID alloc] initWithRecordName:@"QSCompany"]];
    companyRecord[@"name"] = @"new company";
    
    CKRecord *employeeRecord = [[CKRecord alloc] initWithRecordType:@"QSEmployee" recordID:[[CKRecordID alloc] initWithRecordName:@"QSEmployee"]];
    employeeRecord[@"name"] = @"new employee";
    employeeRecord[@"company"] = [[CKReference alloc] initWithRecordID:companyRecord.recordID action:CKReferenceActionNone];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [changeManager prepareForImport];
    [changeManager saveChangesInRecord:employeeRecord];
    [changeManager saveChangesInRecord:companyRecord];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSArray *objects = [self.targetCoreDataStack.managedObjectContext executeFetchRequestWithEntityName:@"QSCompany" error:nil];
    XCTAssertTrue(objects.count == 1);
    QSCompany *company = [objects firstObject];
    XCTAssertTrue([company.name isEqualToString:@"new company"]);
    XCTAssertTrue(company.employees.count == 1);
    if (company.employees.count) {
        QSEmployee *employee = (QSEmployee *)[company.employees anyObject];
        XCTAssertTrue([employee.name isEqualToString:@"new employee"]);
    }
}

- (void)testHasRecordID_missingObject_returnsNO
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    company = nil;
    
    XCTAssertFalse([changeManager hasRecordID:[[CKRecordID alloc] initWithRecordName:@"missing"]]);
}

- (void)testHasRecordID_existingObject_returnsYES
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    company = nil;
    
    XCTAssertTrue([changeManager hasRecordID:objectRecord.recordID]);
}

- (void)testHasChanges_noChanges_returnsNO
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertFalse(changeManager.hasChanges);
}

- (void)testHasChanges_objectChanged_returnsYES
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now change object
    company.name = @"name 2";
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    XCTAssertTrue(changeManager.hasChanges);
}

- (void)testDeleteChangeTracking_deletesStore
{
    //Insert object in context
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    [changeManager deleteChangeTracking];
    
    XCTAssertNil(self.coreDataStack.managedObjectContext);
}

- (void)fullySyncChangeManager:(QSCoreDataChangeManager *)changeManager completion:(void(^)(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error))completion;
{
    [changeManager prepareForImport];
    NSArray *recordsToUpload = [changeManager recordsToUploadWithLimit:1000];
    NSArray *recordIDsToDelete = [changeManager recordIDsMarkedForDeletionWithLimit:1000];
    [changeManager didUploadRecords:recordsToUpload];
    [changeManager didDeleteRecordIDs:recordIDsToDelete];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        completion(recordsToUpload, recordIDsToDelete, error);
        [changeManager didFinishImportWithError:nil];
    }];
}

@end
