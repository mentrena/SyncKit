//
//  QSCoreDataAdapterTests.m
//  SyncKit
//
//  Created by Manuel Entrena on 26/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import <XCTest/XCTest.h>
@import SyncKit;
#import "QSEmployee.h"
#import "QSCompany.h"
#import "QSTestEntity+CoreDataClass.h"
#import "QSNamesTransformer.h"

@interface QSCoreDataAdapterTests : XCTestCase <QSCoreDataAdapterDelegate, QSCoreDataAdapterConflictResolutionDelegate>

@property (nonatomic, strong) QSCoreDataStack *targetCoreDataStack;
@property (nonatomic, strong) QSCoreDataStack *coreDataStack;

@property (nonatomic, assign) BOOL didCallRequestContextSave;
@property (nonatomic, assign) BOOL didCallImportChanges;

@property (nonatomic, copy) void(^customMergePolicyBlock)(QSCoreDataAdapter *coreDataAdapter, NSManagedObject *object, NSDictionary *changes);

@end

@implementation QSCoreDataAdapterTests

- (void)setUp {
    [super setUp];

    self.targetCoreDataStack = [self coreDataStackWithModelName:@"QSExample"];
    self.coreDataStack = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataAdapter persistenceModel] storePath:nil concurrencyType:NSMainQueueConcurrencyType dispatchImmediately:YES];
}

- (QSCoreDataStack *)coreDataStackWithModelName:(NSString *)modelName
{
    NSURL *modelURL = [[NSBundle bundleForClass:[self class]] URLForResource:modelName withExtension:@"momd"];
    QSCoreDataStack *stack = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL] storePath:nil concurrencyType:NSMainQueueConcurrencyType dispatchImmediately:YES];
    return stack;
}

- (void)coreDataAdapterRequestsContextSave:(QSCoreDataAdapter *)coreDataAdapter completion:(void(^)(NSError *))completion
{
    self.didCallRequestContextSave = YES;
    [self.targetCoreDataStack.managedObjectContext performBlockAndWait:^{
        [self.targetCoreDataStack.managedObjectContext save:nil];
    }];
    completion(nil);
}

- (void)coreDataAdapter:(QSCoreDataAdapter *)coreDataAdapter didImportChanges:(NSManagedObjectContext *)importContext completion:(void(^)(NSError *error))completion
{
    self.didCallImportChanges = YES;
    [importContext performBlockAndWait:^{
        [importContext save:nil];
        [coreDataAdapter.targetContext performBlockAndWait:^{
            [coreDataAdapter.targetContext save:nil];
        }];
        completion(nil);
    }];
}

- (void)coreDataAdapter:(QSCoreDataAdapter *)coreDataAdapter gotChanges:(NSDictionary *)changeDictionary forObject:(NSManagedObject *)object
{
    if (self.customMergePolicyBlock) {
        self.customMergePolicyBlock(coreDataAdapter, object, changeDictionary);
    }
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
    [self insertCompanyWithName:@"name1"
                     identifier:@"name1"
                      inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertTrue(self.didCallImportChanges);
    XCTAssertTrue(self.didCallRequestContextSave);
}

- (void)testRecordsToUploadWithLimit_initialSync_returnsRecord
{
    //Insert object in context
    [self insertCompanyWithName:@"new name"
                     identifier:@"id1"
                      inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    [coreDataAdapter prepareForImport];
    NSArray *records = [coreDataAdapter recordsToUploadWithLimit:10];
    [coreDataAdapter didFinishImportWithError:nil];

    XCTAssertTrue(records.count > 0);
    CKRecord *record = [records firstObject];
    XCTAssertTrue([record[@"name"] isEqual:@"new name"]);
}

- (void)testRecordsToUpload_changedObject_returnsRecordWithChanges
{
    //Insert object in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"id1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    //Now change object
    company.name = @"name 2";
    NSError *error;
    [self.targetCoreDataStack.managedObjectContext save:&error];

    //Try to sync again
    [coreDataAdapter prepareForImport];
    NSArray *records = [coreDataAdapter recordsToUploadWithLimit:10];
    [coreDataAdapter didFinishImportWithError:nil];

    XCTAssertTrue(records.count > 0);
    CKRecord *record = [records firstObject];
    XCTAssertTrue([record[@"name"] isEqual:@"name 2"]);
}

- (void)testRecordsToUpload_onlyIncludesToOneRelationships
{
    //Insert object in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];
    [self insertEmployeeWithName:@"employee 1"
                      identifier:@"em1"
                         company:company
                       inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *companyRecord = nil;
    __block CKRecord *employeeRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        for (CKRecord *record in uploadedRecords) {
            if ([record.recordID.recordName hasPrefix:@"QSCompany"]) {
                companyRecord = record;
            } else if ([record.recordID.recordName hasPrefix:@"QSEmployee"]) {
                employeeRecord = record;
            }
        }
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertNil(companyRecord[@"employees"]);
    XCTAssertNotNil(employeeRecord[@"company"]);
}

- (void)testRecordsMarkedForDeletion_deletedObject_returnsRecordID
{
    //Insert object in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    //Now delete object
    [self.targetCoreDataStack.managedObjectContext performBlockAndWait:^{
        [self.targetCoreDataStack.managedObjectContext deleteObject:company];
        [self.targetCoreDataStack.managedObjectContext save:nil];
    }];

    //Try to sync again
    [coreDataAdapter prepareForImport];
    NSArray *records = [coreDataAdapter recordIDsMarkedForDeletionWithLimit:1000];
    [coreDataAdapter didFinishImportWithError:nil];

    XCTAssertTrue(records.count > 0);
}

- (void)testDeleteRecordWithID_deletesCorrespondingObject
{
    //Insert object in context
    [self insertCompanyWithName:@"name 1"
                     identifier:@"com1"
                      inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    //Start sync and delete object
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    [self fullySyncChangeManager:coreDataAdapter downloadedRecords:@[] deletedRecordIDs:@[objectRecord.recordID] completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    NSArray *objects = [self.targetCoreDataStack.managedObjectContext executeFetchRequestWithEntityName:@"QSCompany" error:nil];
    XCTAssertTrue(objects.count == 0);
}

- (void)testSaveChangesInRecord_existingObject_updatesObject
{
    //Insert object in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    objectRecord[@"name"] = @"name 2";

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];

    //Start sync and delete object
    [self fullySyncChangeManager:coreDataAdapter downloadedRecords:@[objectRecord] deletedRecordIDs:@[] completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.targetCoreDataStack.managedObjectContext refreshObject:company mergeChanges:NO];
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
}

- (void)testSaveChangesInRecord_newObject_insertsObject
{
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    CKRecord *objectRecord = [[CKRecord alloc] initWithRecordType:@"QSCompany" recordID:[[CKRecordID alloc] initWithRecordName:@"QSCompany.com1"]];
    objectRecord[@"name"] = @"new company";

    XCTestExpectation *expectation = [self expectationWithDescription:@"merged changes"];

    //Start sync and delete object
    [coreDataAdapter prepareForImport];
    [coreDataAdapter saveChangesInRecords:@[objectRecord]];
    [coreDataAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [coreDataAdapter didFinishImportWithError:nil];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    NSArray *objects = [self.targetCoreDataStack.managedObjectContext executeFetchRequestWithEntityName:@"QSCompany" error:nil];
    XCTAssertTrue(objects.count == 1);
    QSCompany *company = [objects firstObject];
    XCTAssertTrue([company.name isEqualToString:@"new company"]);
    XCTAssertTrue([company.identifier isEqualToString:@"com1"]);
}

- (void)testSaveChangesInRecord_missingProperty_setsPropertyToNil
{
    //Insert object in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    objectRecord[@"name"] = nil;

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];

    //Start sync and delete object
    [self fullySyncChangeManager:coreDataAdapter downloadedRecords:@[objectRecord] deletedRecordIDs:@[] completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.targetCoreDataStack.managedObjectContext refreshObject:company mergeChanges:NO];
    XCTAssertNil(company.name);
}

- (void)testSaveChangesInRecord_missingRelationshipProperty_setsPropertyToNil
{
    //Insert object in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];
    
    QSEmployee *employee = [self insertEmployeeWithName:@"employee 1"
                                             identifier:@"em1"
                                                company:company
                                              inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        for (CKRecord *record in uploadedRecords) {
            if ([record.recordID.recordName hasPrefix:@"QSEmployee"]) {
                objectRecord = record;
            }
        }
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    objectRecord[@"company"] = nil;

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];

    //Start sync and delete object
    [self fullySyncChangeManager:coreDataAdapter downloadedRecords:@[objectRecord] deletedRecordIDs:@[] completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.targetCoreDataStack.managedObjectContext refreshObject:employee mergeChanges:NO];
    XCTAssertNil(employee.company);
}

- (void)testSaveChangesInRecord_missingToManyRelationshipProperty_doesNothing
{
    //Insert object in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];
    
    [self insertEmployeeWithName:@"employee 1"
                      identifier:@"em1"
                         company:company
                       inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        for (CKRecord *record in uploadedRecords) {
            if ([record.recordID.recordName hasPrefix:@"QSCompany"]) {
                objectRecord = [uploadedRecords firstObject];
            }
        }
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    objectRecord[@"employees"] = nil;

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];

    //Start sync and delete object
    [self fullySyncChangeManager:coreDataAdapter downloadedRecords:@[objectRecord] deletedRecordIDs:@[] completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.targetCoreDataStack.managedObjectContext refreshObject:company mergeChanges:NO];
    XCTAssertNotNil(company.employees);
}

- (void)testSync_multipleObjects_preservesRelationships
{
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    CKRecord *companyRecord = [[CKRecord alloc] initWithRecordType:@"QSCompany" recordID:[[CKRecordID alloc] initWithRecordName:@"QSCompany.com1"]];
    companyRecord[@"name"] = @"new company";

    CKRecord *employeeRecord = [[CKRecord alloc] initWithRecordType:@"QSEmployee" recordID:[[CKRecordID alloc] initWithRecordName:@"QSEmployee.em1"]];
    employeeRecord[@"name"] = @"new employee";
    employeeRecord[@"company"] = [[CKReference alloc] initWithRecordID:companyRecord.recordID action:CKReferenceActionNone];

    XCTestExpectation *expectation = [self expectationWithDescription:@"merged changes"];

    //Start sync and delete object
    [coreDataAdapter prepareForImport];
    [coreDataAdapter saveChangesInRecords:@[employeeRecord, companyRecord]];
    [coreDataAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [coreDataAdapter didFinishImportWithError:nil];

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
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    company = nil;

    XCTAssertFalse([coreDataAdapter hasRecordID:[[CKRecordID alloc] initWithRecordName:@"missing"]]);
}

- (void)testHasRecordID_existingObject_returnsYES
{
    //Insert object in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    company = nil;

    XCTAssertTrue([coreDataAdapter hasRecordID:objectRecord.recordID]);
}

- (void)testHasChanges_noChanges_returnsNO
{
    //Insert object in context
    [self insertCompanyWithName:@"name 1"
                     identifier:@"com1"
                      inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertFalse(coreDataAdapter.hasChanges);
}

- (void)testHasChanges_objectChanged_returnsYES
{
    //Insert object in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    //Now change object
    NSError *error;
    company.name = @"name 2";
    [self.targetCoreDataStack.managedObjectContext save:&error];

    XCTAssertTrue(coreDataAdapter.hasChanges);
}

- (void)testHasChanges_afterSuccessfulSync_returnsNO
{
    //Insert object in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    NSError *error;
    company.name = @"name 2";
    [self.targetCoreDataStack.managedObjectContext save:&error];

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertFalse(coreDataAdapter.hasChanges);
}

- (void)testDeleteChangeTracking_deletesStore
{
    //Insert object in context
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    [coreDataAdapter deleteChangeTracking];

    XCTAssertNil(self.coreDataStack.managedObjectContext);
}

- (void)testRecordsToUpload_partialUploadSuccess_stillReturnsPendingRecords
{
    //Insert object in context
    [self insertCompanyWithName:@"name 1"
                     identifier:@"com1"
                      inContext:self.targetCoreDataStack.managedObjectContext];
    [self insertCompanyWithName:@"name 2"
                     identifier:@"com2"
                      inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    //Sync
    [coreDataAdapter prepareForImport];
    NSArray *recordsToUpload = [coreDataAdapter recordsToUploadWithLimit:1000];
    [coreDataAdapter didUploadRecords:@[recordsToUpload.firstObject]];
    [coreDataAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [coreDataAdapter didFinishImportWithError:error];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    NSArray *recordsToUploadAfterSync = [coreDataAdapter recordsToUploadWithLimit:1000];

    XCTAssertTrue(recordsToUpload.count == 2);
    XCTAssertTrue(recordsToUploadAfterSync.count == 1);
}

- (void)testRecordsToUpload_doesNotIncludeObjectsWithOnlyToManyRelationshipChanges
{
    //Insert objects in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];

    QSEmployee *employee1 = [self insertEmployeeWithName:@"employee1"
                                              identifier:@"em1"
                                                 company:company
                                               inContext:self.targetCoreDataStack.managedObjectContext];
    QSEmployee *employee2 = [self insertEmployeeWithName:@"employee2"
                                              identifier:@"em2"
                                                 company:company
                                               inContext:self.targetCoreDataStack.managedObjectContext];

    //Create change manager and sync
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    //Now change to-many relationship
    NSError *error;
    company.employees = [NSSet setWithObjects:employee1, employee2, nil];
    employee1.name = @"employee 1-2";
    [self.targetCoreDataStack.managedObjectContext save:&error];

    //Try to sync again and check that we don't get a record for the company object
    [coreDataAdapter prepareForImport];
    NSArray *records = [coreDataAdapter recordsToUploadWithLimit:10];
    [coreDataAdapter didFinishImportWithError:nil];

    CKRecord *companyRecord = nil;
    NSMutableSet *employeeRecords = [NSMutableSet set];
    for (CKRecord *record in records) {
        if ([record.recordType isEqualToString:@"QSCompany"]) {
            companyRecord = record;
        } else if ([record.recordType isEqualToString:@"QSEmployee"]) {
            [employeeRecords addObject:record];
        }
    }
    XCTAssertTrue(records.count == 1);
    XCTAssertTrue(employeeRecords.count == 1);
    XCTAssertNil(companyRecord);
}

- (void)testRecordsToUpload_whenRecordWasDownloadedForObject_usesCorrectRecordVersion
{
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    // Can't set up CKRecord object so we'll use an existing one for the test
    NSData *data = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"QSCompany.1739C6A5-C07E-48A5-B83E-AB07694F23DF" withExtension:@""]];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    CKRecord *record = [[CKRecord alloc] initWithCoder:unarchiver];
    [unarchiver finishDecoding];

    // Keep track of the record change tag
    NSString *recordChangeTag = record.recordChangeTag;

    record[@"name"] = @"new company";

    XCTestExpectation *expectation = [self expectationWithDescription:@"merged changes"];

    //Start sync and save record
    [coreDataAdapter prepareForImport];
    [coreDataAdapter saveChangesInRecords:@[record]];
    [coreDataAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [coreDataAdapter didFinishImportWithError:nil];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    // Now change object so it produces a record to upload

    NSArray *objects = [self.targetCoreDataStack.managedObjectContext executeFetchRequestWithEntityName:@"QSCompany" error:nil];
    QSCompany *company = [objects firstObject];
    company.name = @"another name";
    [self.targetCoreDataStack.managedObjectContext save:nil];


    // Sync
    [coreDataAdapter prepareForImport];
    NSArray *records = [coreDataAdapter recordsToUploadWithLimit:10];
    [coreDataAdapter didFinishImportWithError:nil];

    CKRecord *uploadedRecord = [records firstObject];
    XCTAssertEqual(uploadedRecord.recordChangeTag, recordChangeTag);
}

#pragma mark - CKAsset

- (void)testRecordToUpload_dataProperty_uploadedAsAsset
{
    //Insert object in context
    QSEmployee *employee = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSEmployee class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    employee.name = @"employee 1";
    employee.identifier = [[NSUUID UUID] UUIDString];
    employee.photo = [NSData data];
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    CKAsset *asset = objectRecord[@"photo"];
    XCTAssertTrue([asset isKindOfClass:[CKAsset class]]);
    XCTAssertNotNil(asset.fileURL);
}

- (void)testRecordToUpload_dataProperty_forceDataType_uploadedAsData
{
    //Insert object in context
    QSEmployee *employee = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSEmployee class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    employee.name = @"employee 1";
    employee.identifier = [[NSUUID UUID] UUIDString];
    employee.photo = [NSData data];
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    coreDataAdapter.forceDataTypeInsteadOfAsset = YES;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSData *photo = objectRecord[@"photo"];
    XCTAssertTrue([photo isKindOfClass:[NSData class]]);
}

- (void)testRecordToUpload_dataPropertyNil_nilsProperty
{
    //Insert object in context
    QSEmployee *employee = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSEmployee class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    employee.name = @"employee 1";
    employee.identifier = [[NSUUID UUID] UUIDString];
    employee.photo = [NSData data];
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    employee.photo = nil;

    [self.targetCoreDataStack.managedObjectContext save:nil];

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    CKAsset *asset = objectRecord[@"photo"];
    XCTAssertNil(asset);
}

- (void)testSaveChangesInRecord_assetProperty_updatesData
{
    //Insert object in context
    QSEmployee *employee = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSEmployee class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    employee.name = @"employee 1";
    employee.identifier = [[NSUUID UUID] UUIDString];
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    char photoBytes[8];
    NSData *data = [NSData dataWithBytes:photoBytes length:8];
    NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"test"]];
    [data writeToURL:fileURL atomically:YES];
    CKAsset *asset = [[CKAsset alloc] initWithFileURL:fileURL];
    objectRecord[@"photo"] = asset;

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter downloadedRecords:@[objectRecord] deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];

    [self.targetCoreDataStack.managedObjectContext refreshObject:employee mergeChanges:NO];
    XCTAssertNotNil(employee.photo);
    XCTAssertEqual([employee.photo length], 8);
}

- (void)testSaveChangesInRecord_assetPropertyNil_nilsData
{
    //Insert object in context
    QSEmployee *employee = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSEmployee class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    employee.name = @"employee 1";
    employee.identifier = [[NSUUID UUID] UUIDString];
    employee.photo = [NSData data];
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];

        QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    objectRecord[@"photo"] = nil;

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter downloadedRecords:@[objectRecord] deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.targetCoreDataStack.managedObjectContext refreshObject:employee mergeChanges:NO];
    XCTAssertNil(employee.photo);
}

#pragma mark - Unique objects

- (void)testSaveChangesInRecord_existingUniqueObject_updatesObject
{
    //Insert object in context
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    objectRecord[@"name"] = @"name 2";

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];

    //Start sync and delete object
    [coreDataAdapter prepareForImport];
    [coreDataAdapter saveChangesInRecords:@[objectRecord]];
    [coreDataAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [coreDataAdapter didFinishImportWithError:nil];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.targetCoreDataStack.managedObjectContext refreshObject:company mergeChanges:NO];
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
}

- (void)testRecordsToUpload_uniqueObjectsWithSameID_mapsObjectsToSameRecord
{
    
    QSCoreDataStack *target2 = [self coreDataStackWithModelName:@"QSExample"];
    QSCoreDataStack *persistence2 = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataAdapter persistenceModel] storePath:nil concurrencyType:NSPrivateQueueConcurrencyType dispatchImmediately:YES];

    //Insert object in context
    QSCompany *company = [self insertAndSaveObjectOfType:@"QSCompany"
                                               properties:@{@"name": @"name 1",
                                                            @"identifier": [[NSUUID UUID] UUIDString]
                                                            }
                                              intoContext:self.targetCoreDataStack.managedObjectContext];

    //Insert object with same identifier in the other stack
    [self insertAndSaveObjectOfType:@"QSCompany"
                         properties:@{@"name": @"name 2",
                                      @"identifier": company.identifier}
                        intoContext:target2.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    QSCoreDataAdapter *coreDataAdapter2 = [[QSCoreDataAdapter alloc] initWithPersistenceStack:persistence2 targetContext:target2.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    //Get records to upload

    [coreDataAdapter prepareForImport];
    NSArray *records = [coreDataAdapter recordsToUploadWithLimit:10];
    [coreDataAdapter didFinishImportWithError:nil];

    [coreDataAdapter2 prepareForImport];
    NSArray *records2 = [coreDataAdapter2 recordsToUploadWithLimit:10];
    [coreDataAdapter2 didFinishImportWithError:nil];

    XCTAssertTrue(records.count == 1);
    XCTAssertTrue(records2.count == 1);

    CKRecord *record = [records firstObject];
    CKRecord *record2 = [records2 firstObject];

    XCTAssertTrue([record.recordID.recordName isEqualToString:record2.recordID.recordName]);
}

- (void)testSync_uniqueObjectsWithSameID_updatesObjectCorrectly
{
    QSCoreDataStack *target2 = [self coreDataStackWithModelName:@"QSExample"];
    QSCoreDataStack *persistence2 = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataAdapter persistenceModel] storePath:nil concurrencyType:NSPrivateQueueConcurrencyType dispatchImmediately:YES];

    //Insert object in context
    QSCompany *company = [self insertAndSaveObjectOfType:@"QSCompany"
                                               properties:@{@"name": @"name 1",
                                                            @"identifier": [[NSUUID UUID] UUIDString]
                                                            }
                                              intoContext:self.targetCoreDataStack.managedObjectContext];

    QSCompany *company2 = [self insertAndSaveObjectOfType:@"QSCompany"
                                                properties:@{@"name": @"name 2",
                                                             @"identifier": company.identifier}
                                               intoContext:target2.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    QSCoreDataAdapter *coreDataAdapter2 = [[QSCoreDataAdapter alloc] initWithPersistenceStack:persistence2 targetContext:target2.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {

        [self fullySyncChangeManager:coreDataAdapter2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    [target2.managedObjectContext refreshObject:company2 mergeChanges:NO];

    XCTAssertTrue([company2.name isEqualToString:@"name 1"]);
}

- (void)testRecordsToUpload_doesNotIncludePrimaryKey
{
    //Insert object in context
    [self insertCompanyWithName:@"name 1"
                     identifier:@"com1"
                      inContext:self.targetCoreDataStack.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertNil(objectRecord[@"identifier"]);
    XCTAssertNotNil(objectRecord[@"name"]);
}

- (void)testSaveChangesInRecords_ignoresPrimaryKeyField
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSString *identifier = [[NSUUID UUID] UUIDString];
    company.identifier = identifier;
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    objectRecord[@"identifier"] = @"fake identifier";
    objectRecord[@"name"] = @"name 2";

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];

    //Start sync and delete object
    [coreDataAdapter prepareForImport];
    [coreDataAdapter saveChangesInRecords:@[objectRecord]];
    [coreDataAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [coreDataAdapter didFinishImportWithError:nil];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self.targetCoreDataStack.managedObjectContext refreshObject:company mergeChanges:NO];
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
    XCTAssertEqual(company.identifier, identifier);
}

#pragma mark - Merge policies

- (void)testSync_serverMergePolicy_prioritizesDownloadedChanges
{
    
    QSCoreDataStack *target2 = [self coreDataStackWithModelName:@"QSExample"];
    QSCoreDataStack *persistence2 = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataAdapter persistenceModel] storePath:nil concurrencyType:NSPrivateQueueConcurrencyType dispatchImmediately:YES];

    //Insert object in context
    QSCompany *company = [self insertAndSaveObjectOfType:@"QSCompany"
                                               properties:@{@"name": @"name 1",
                                                            @"identifier": [[NSUUID UUID] UUIDString]
                                                            }
                                              intoContext:self.targetCoreDataStack.managedObjectContext];

    QSCompany *company2 = [self insertAndSaveObjectOfType:@"QSCompany"
                                                properties:@{@"name": @"name 2",
                                                             @"identifier": company.identifier}
                                               intoContext:target2.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    QSCoreDataAdapter *coreDataAdapter2 = [[QSCoreDataAdapter alloc] initWithPersistenceStack:persistence2 targetContext:target2.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {

        [self fullySyncChangeManager:coreDataAdapter2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    [target2.managedObjectContext refreshObject:company2 mergeChanges:NO];

    XCTAssertTrue([company2.name isEqualToString:@"name 1"]);
}

- (void)testSync_clientMergePolicy_prioritizesLocalChanges
{
    
    QSCoreDataStack *target2 = [self coreDataStackWithModelName:@"QSExample"];
    QSCoreDataStack *persistence2 = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataAdapter persistenceModel] storePath:nil concurrencyType:NSPrivateQueueConcurrencyType dispatchImmediately:YES];

    //Insert object in context
    QSCompany *company = [self insertAndSaveObjectOfType:@"QSCompany"
                                               properties:@{@"name": @"name 1",
                                                            @"identifier": [[NSUUID UUID] UUIDString]
                                                            }
                                              intoContext:self.targetCoreDataStack.managedObjectContext];

    QSCompany *company2 = [self insertAndSaveObjectOfType:@"QSCompany"
                                                properties:@{@"name": @"name 2",
                                                             @"identifier": company.identifier}
                                               intoContext:target2.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    QSCoreDataAdapter *coreDataAdapter2 = [[QSCoreDataAdapter alloc] initWithPersistenceStack:persistence2 targetContext:target2.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    coreDataAdapter2.mergePolicy = QSModelAdapterMergePolicyClient;

    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {

        [self fullySyncChangeManager:coreDataAdapter2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    [target2.managedObjectContext refreshObject:company2 mergeChanges:NO];

    XCTAssertTrue([company2.name isEqualToString:@"name 2"]);
}

- (void)testSync_customMergePolicy_callsDelegateForResolution
{
    
    QSCoreDataStack *target2 = [self coreDataStackWithModelName:@"QSExample"];
    QSCoreDataStack *persistence2 = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataAdapter persistenceModel] storePath:nil concurrencyType:NSPrivateQueueConcurrencyType dispatchImmediately:YES];

    //Insert object in context
    QSCompany *company = [self insertAndSaveObjectOfType:@"QSCompany"
                                               properties:@{@"name": @"name 1",
                                                            @"identifier": [[NSUUID UUID] UUIDString]
                                                            }
                                              intoContext:self.targetCoreDataStack.managedObjectContext];

    QSCompany *company2 = [self insertAndSaveObjectOfType:@"QSCompany"
                                                properties:@{@"name": @"name 2",
                                                             @"identifier": company.identifier}
                                               intoContext:target2.managedObjectContext];

    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    QSCoreDataAdapter *coreDataAdapter2 = [[QSCoreDataAdapter alloc] initWithPersistenceStack:persistence2 targetContext:target2.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    coreDataAdapter2.conflictDelegate = self;
    coreDataAdapter2.mergePolicy = QSModelAdapterMergePolicyCustom;

    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block BOOL calledCustomMergePolicyMethod = NO;
    self.customMergePolicyBlock = ^(QSCoreDataAdapter *coreDataAdapter, NSManagedObject *object, NSDictionary *changes) {
        if (coreDataAdapter == coreDataAdapter2 && [object isKindOfClass:[QSCompany class]] && [[changes objectForKey:@"name"] isEqualToString:@"name 1"]) {
            calledCustomMergePolicyMethod = YES;
            [object setValue:@"name 3" forKey:@"name"];
        }
    };

    [self fullySyncChangeManager:coreDataAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {

        [self fullySyncChangeManager:coreDataAdapter2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    [target2.managedObjectContext refreshObject:company2 mergeChanges:NO];

    XCTAssertTrue(calledCustomMergePolicyMethod);
    XCTAssertTrue([company2.name isEqualToString:@"name 3"]);
}

#pragma mark - Other

- (void)testRecordZoneID_returnsZoneID
{
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    CKRecordZoneID *zoneID = coreDataAdapter.recordZoneID;
    XCTAssertEqual(zoneID.ownerName, @"owner");
    XCTAssertEqual(zoneID.zoneName, @"zone");
}

- (void)testServerChangeToken_noToken_returnsNil
{
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    CKServerChangeToken *token = coreDataAdapter.serverChangeToken;
    XCTAssertNil(token);
}

- (void)testServerChangeToken_savedToken_returnsToken
{
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    NSData *data = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"serverChangeToken.AQAAAWPa1DUC" withExtension:@""]];
    CKServerChangeToken *token = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    [coreDataAdapter saveToken:token];
    
    CKServerChangeToken *token2 = coreDataAdapter.serverChangeToken;
    
    XCTAssertTrue([token isEqual:token2]);
}

#pragma mark - Sharing

- (void)testRecordForObjectWithIdentifier_noObject_returnsNil
{
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    CKRecord *record = [coreDataAdapter recordForObject:nil];
    XCTAssertNil(record);
}

- (void)testRecordForObjectWithIdentifier_existingObject_returnsRecord
{
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];
    
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    CKRecord *record = [coreDataAdapter recordForObject:company];
    XCTAssertNotNil(record);
    XCTAssertTrue([record.recordID.recordName hasPrefix:@"QSCompany"]);
}

- (void)testShareForObjectWithIdentifier_noShare_returnsNil
{
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];
    
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    CKShare *share = [coreDataAdapter shareForObject:company];
    XCTAssertNil(share);
}

- (void)testShareForObjectWithIdentifier_saveShareCalled_returnsShare
{
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];
    
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    CKRecord *record = [coreDataAdapter recordForObject:company];
    CKShare *share = [[CKShare alloc] initWithRootRecord:record];
    
    [coreDataAdapter saveShare:share forObject:company];
    
    CKShare *share2 = [coreDataAdapter shareForObject:company];
    XCTAssertNotNil(share2);
}

- (void)testShareForObjectWithIdentifier_shareDeleted_returnsNil
{
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];
    
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    CKRecord *record = [coreDataAdapter recordForObject:company];
    CKShare *share = [[CKShare alloc] initWithRootRecord:record];
    
    [coreDataAdapter saveShare:share forObject:company];
    
    [coreDataAdapter deleteShareForObject:company];
    CKShare *share2 = [coreDataAdapter shareForObject:company];
    XCTAssertNil(share2);
}

- (void)testSaveChangesInRecords_includesShare_savesObjectAndShare
{
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];

    CKRecord *companyRecord = [[CKRecord alloc] initWithRecordType:@"QSCompany" recordID:[[CKRecordID alloc] initWithRecordName:@"QSCompany.com1"]];
    companyRecord[@"name"] = @"new company";

    CKShare *shareRecord = [[CKShare alloc] initWithRootRecord:companyRecord shareID:[[CKRecordID alloc] initWithRecordName:@"QSShare.forCompany"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    [self fullySyncChangeManager:coreDataAdapter downloadedRecords:@[companyRecord, shareRecord] deletedRecordIDs:@[] completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    QSCompany *company = [[self.targetCoreDataStack.managedObjectContext executeFetchRequestWithEntityName:@"QSCompany" error:nil] firstObject];
    CKShare *share = [coreDataAdapter shareForObject:company];
    
    XCTAssertNotNil(company);
    XCTAssertNotNil(share);
    XCTAssertTrue([company.name isEqualToString:@"new company"]);
    XCTAssertTrue([share.recordID.recordName isEqualToString:@"QSShare.forCompany"]);
}

- (void)testDeleteRecordsWithIDs_containsShare_deletesShare
{
    QSCompany *company = [self insertCompanyWithName:@"name 1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];
    
    CKRecordZoneID *zoneID = [[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"];
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:zoneID delegate:self];
    
    CKRecord *record = [coreDataAdapter recordForObject:company];
    CKRecordID *shareID = [[CKRecordID alloc] initWithRecordName:@"CKShare.identifier" zoneID:zoneID];
    CKShare *share = [[CKShare alloc] initWithRootRecord:record shareID:shareID];
    
    [coreDataAdapter saveShare:share forObject:company];
    
    CKShare *savedShare = [coreDataAdapter shareForObject:company];
    XCTAssertNotNil(savedShare);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    [self fullySyncChangeManager:coreDataAdapter downloadedRecords:@[] deletedRecordIDs:@[shareID] completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    CKShare *updatedShare = [coreDataAdapter shareForObject:company];
    XCTAssertNil(updatedShare);
}

- (void)testRecordsToUpdateParentRelationshipsForRoot_returnsRecords
{
    QSCompany *company = [self insertCompanyWithName:@"com1"
                                          identifier:@"com1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];
    QSCompany *company2 = [self insertCompanyWithName:@"com2"
                                           identifier:@"com2"
                                            inContext:self.targetCoreDataStack.managedObjectContext];
    [self insertEmployeeWithName:@"emp1"
                      identifier:@"emp1"
                         company:company
                       inContext:self.targetCoreDataStack.managedObjectContext];
    [self insertEmployeeWithName:@"emp2"
                      identifier:@"emp2"
                         company:company
                       inContext:self.targetCoreDataStack.managedObjectContext];
    [self insertEmployeeWithName:@"emp3"
                      identifier:@"emp3"
                         company:company2
                       inContext:self.targetCoreDataStack.managedObjectContext];
    [self insertEmployeeWithName:@"emp3"
                      identifier:@"emp3"
                         company:company2
                       inContext:self.targetCoreDataStack.managedObjectContext];
    
    CKRecordZoneID *zoneID = [[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"];
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:zoneID delegate:self];
    
    NSArray<CKRecord *> *records = [coreDataAdapter recordsToUpdateParentRelationshipsForRoot:company];
    
    XCTAssertEqual(records.count, 3);
    for (CKRecord *record in records) {
        XCTAssertTrue([record.recordID.recordName containsString:@"com1"] ||
                      [record.recordID.recordName containsString:@"emp1"] ||
                      [record.recordID.recordName containsString:@"emp2"]);
    }
}

- (void)testRecordsToUpload_includesAnyParentRecordsInBatch
{
    QSCompany *company = [self insertCompanyWithName:@"new name"
                                          identifier:@"id1"
                                           inContext:self.targetCoreDataStack.managedObjectContext];
    [self insertEmployeeWithName:@"employee1"
                      identifier:@"em1"
                         company:company
                       inContext:self.targetCoreDataStack.managedObjectContext];
    
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    [coreDataAdapter prepareForImport];
    NSArray *records = [coreDataAdapter recordsToUploadWithLimit:1];
    [coreDataAdapter didFinishImportWithError:nil];
    
    XCTAssertEqual(records.count, 2);
    BOOL includesCompany = NO;
    BOOL includesEmployee = NO;
    for (CKRecord *record in records) {
        if ([record.recordID.recordName containsString:@"id1"]) {
            includesCompany = YES;
        }
        if ([record.recordID.recordName containsString:@"em1"]) {
            includesEmployee = YES;
        }
    }
}

#pragma mark - Transformable

- (void)testRecordsToUploadWithLimit_transformableProperty_usesValueTransformer
{
    [QSNamesTransformer resetValues];
    self.targetCoreDataStack = [self coreDataStackWithModelName:@"QSTransformableTestModel"];
    
    //Insert object in context
    QSTestEntity *entity = [NSEntityDescription insertNewObjectForEntityForName:@"QSTestEntity" inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    entity.identifier = @"identifier";
    entity.names = @[@"1", @"2"];
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    [coreDataAdapter prepareForImport];
    NSArray *records = [coreDataAdapter recordsToUploadWithLimit:10];
    [coreDataAdapter didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count > 0);
    XCTAssertTrue([QSNamesTransformer transformedValueCalled]);
    XCTAssertFalse([QSNamesTransformer reverseTransformedValueCalled]);
}

- (void)testSaveChangesInRecords_transformableProperty_usesValueTransformer
{
    [QSNamesTransformer resetValues];
    self.targetCoreDataStack = [self coreDataStackWithModelName:@"QSTransformableTestModel"];
    
    QSCoreDataAdapter *coreDataAdapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    NSArray *array = @[@"1", @"2", @"3"];
    
    CKRecord *objectRecord = [[CKRecord alloc] initWithRecordType:@"QSTestEntity" recordID:[[CKRecordID alloc] initWithRecordName:@"QSTestEntity.ent1"]];
    objectRecord[@"identifier"] = @"ent1";
    objectRecord[@"names"] = [NSKeyedArchiver archivedDataWithRootObject:array];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [coreDataAdapter prepareForImport];
    [coreDataAdapter saveChangesInRecords:@[objectRecord]];
    [coreDataAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [coreDataAdapter didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSArray *objects = [self.targetCoreDataStack.managedObjectContext executeFetchRequestWithEntityName:@"QSTestEntity" error:nil];
    XCTAssertTrue(objects.count == 1);
    QSTestEntity *testEntity = [objects firstObject];
    XCTAssertTrue([[testEntity valueForKey:@"identifier"] isEqualToString:@"ent1"]);
    XCTAssertTrue([[testEntity valueForKey:@"names"] isEqualToArray:array]);
    XCTAssertTrue([QSNamesTransformer reverseTransformedValueCalled]);
    XCTAssertFalse([QSNamesTransformer transformedValueCalled]);
}

#pragma mark - Utilities

- (id)insertAndSaveObjectOfType:(NSString *)entityType properties:(NSDictionary *)properties intoContext:(NSManagedObjectContext *)context
{
    NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:entityType inManagedObjectContext:context];
    [properties enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [object setValue:obj forKey:key];
    }];
    NSError *error = nil;
    [context save:&error];
    return object;
}

- (QSCompany *)insertCompanyWithName:(NSString *)name identifier:(NSString *)identifier inContext:(NSManagedObjectContext *)context
{
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:@"QSCompany" inManagedObjectContext:context];
    company.name = name;
    company.identifier = identifier;
    NSError *error = nil;
    [context save:&error];
    return company;
}

- (QSEmployee *)insertEmployeeWithName:(NSString *)name identifier:(NSString *)identifier company:(QSCompany *)company inContext:(NSManagedObjectContext *)context
{
    QSEmployee *employee = [NSEntityDescription insertNewObjectForEntityForName:@"QSEmployee" inManagedObjectContext:context];
    employee.name = name;
    employee.identifier = identifier;
    employee.company = company;
    NSError *error = nil;
    [context save:&error];
    return employee;
}

- (void)fullySyncChangeManager:(QSCoreDataAdapter *)coreDataAdapter completion:(void(^)(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error))completion
{
    [coreDataAdapter prepareForImport];
    NSArray *recordsToUpload = [coreDataAdapter recordsToUploadWithLimit:1000];
    NSArray *recordIDsToDelete = [coreDataAdapter recordIDsMarkedForDeletionWithLimit:1000];
    [coreDataAdapter didUploadRecords:recordsToUpload];
    [coreDataAdapter didDeleteRecordIDs:recordIDsToDelete];
    [coreDataAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [coreDataAdapter didFinishImportWithError:nil];
        completion(recordsToUpload, recordIDsToDelete, error);
    }];
}

- (void)fullySyncChangeManager:(id<QSModelAdapter>)coreDataAdapter downloadedRecords:(NSArray *)records deletedRecordIDs:(NSArray *)recordIDs completion:(void(^)(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error))completion
{
    [coreDataAdapter prepareForImport];
    [coreDataAdapter saveChangesInRecords:records];
    [coreDataAdapter deleteRecordsWithIDs:recordIDs];

    [coreDataAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        NSArray *recordsToUpload = nil;
        NSArray *recordIDsToDelete = nil;
        if (!error) {
            recordsToUpload = [coreDataAdapter recordsToUploadWithLimit:1000];
            recordIDsToDelete = [coreDataAdapter recordIDsMarkedForDeletionWithLimit:1000];
            [coreDataAdapter didUploadRecords:recordsToUpload];
            [coreDataAdapter didDeleteRecordIDs:recordIDsToDelete];
        }

        [coreDataAdapter didFinishImportWithError:error];
        completion(recordsToUpload, recordIDsToDelete, error);
    }];
}

@end
