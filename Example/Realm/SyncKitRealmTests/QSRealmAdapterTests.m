//
//  QSRealmAdapterTests.m
//  SyncKitRealm
//
//  Created by Manuel Entrena on 07/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QSCompany.h"
#import "QSEmployee.h"
#import <Realm/Realm.h>
@import SyncKit;

@interface QSRealmAdapterTests : XCTestCase <QSRealmAdapterDelegate>

@property (nonatomic, copy) void(^customMergePolicyBlock)(QSRealmAdapter *realmAdapter, NSDictionary *changes, RLMObject *object);

@end

@implementation QSRealmAdapterTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - Tests

- (void)testRecordsToUploadWithLimit_initialSync_returnsRecord
{
    //Insert object in context
    RLMRealm *realm = [self realmWithIdentifier:@"t1"];
    [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p1"]];
    
    [realmAdapter prepareForImport];
    NSArray *records = [realmAdapter recordsToUploadWithLimit:10];
    [realmAdapter didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count > 0, @"Expect one record to upload");
    CKRecord *record = [records firstObject];
    XCTAssertTrue([record[@"name"] isEqual:@"company1"], @"Name in record should be 'company1'");
}

- (void)testRecordsToUpload_changedObject_returnsRecordWithChanges
{
    RLMRealm *realm = [self realmWithIdentifier:@"t2"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p2"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now change object
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    // Realm seems to delay delivery of notifications for deleted objects so we need to give it a chance to do so
    [self waitForHasChangesNotificationFromAdapter:realmAdapter];
    
    //Try to sync again
    [realmAdapter prepareForImport];
    NSArray *records = [realmAdapter recordsToUploadWithLimit:10];
    [realmAdapter didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count > 0);
    CKRecord *record = [records firstObject];
    XCTAssertTrue([record[@"name"] isEqual:@"name 2"]);
}

- (void)testRecordsToUpload_includesOnlyToOneRelationships
{
    RLMRealm *realm = [self realmWithIdentifier:@"t30"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    [self insertEmployeeWithValues:@{@"identifier": @"2", @"company": company, @"name": @"employee1"} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p30"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    __block CKRecord *companyRecord = nil;
    __block CKRecord *employeeRecord = nil;
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    
    XCTAssertNotNil(employeeRecord[@"company"]);
    XCTAssertNil(companyRecord[@"employees"]);
}

- (void)testRecordsMarkedForDeletion_deletedObject_returnsRecordID
{
    RLMRealm *realm = [self realmWithIdentifier:@"t3"];
    // Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p3"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // Now delete object
    [realm beginWriteTransaction];
    [realm deleteObject:company];
    [realm commitWriteTransaction];
    
    // Realm seems to delay delivery of notifications for deleted objects so we need to give it a chance to do so
    XCTestExpectation *waitExpectation = [self expectationWithDescription:@"give Realm time to deliver notifications"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [waitExpectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // Try to sync again
    [realmAdapter prepareForImport];
    NSArray *records = [realmAdapter recordIDsMarkedForDeletionWithLimit:1000];
    [realmAdapter didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count > 0);
    XCTAssertTrue([[[records firstObject] recordName] isEqualToString:@"QSCompany.1"]);
}

- (void)testDeleteRecordWithID_deletesCorrespondingObject
{
    RLMRealm *realm = [self realmWithIdentifier:@"t4"];
    // Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p4"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    company = nil;
    
    //Start sync and delete object
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    [self fullySyncAdapter:realmAdapter downloadedRecords:@[] deletedRecordIDs:@[objectRecord.recordID] completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    RLMResults *objects = [QSCompany allObjectsInRealm:realm];
    XCTAssertTrue(objects.count == 0);
}

- (void)testSaveChangesInRecord_existingObject_updatesObject
{
    RLMRealm *realm = [self realmWithIdentifier:@"t5"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p5"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    objectRecord[@"name"] = @"name 2";
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [realmAdapter prepareForImport];
    [realmAdapter saveChangesInRecords:@[objectRecord]];
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [realmAdapter didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
}

- (void)testSaveChangesInRecord_newObject_insertsObject
{
    RLMRealm *realm = [self realmWithIdentifier:@"t6"];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p6"]];
    
    CKRecord *objectRecord = [[CKRecord alloc] initWithRecordType:@"QSCompany" recordID:[[CKRecordID alloc] initWithRecordName:@"QSCompany.1"]];
    objectRecord[@"name"] = @"new company";
    objectRecord[@"identifier"] = @"1";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [realmAdapter prepareForImport];
    [realmAdapter saveChangesInRecords:@[objectRecord]];
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [realmAdapter didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    RLMResults *objects = [QSCompany allObjectsInRealm:realm];
    XCTAssertTrue(objects.count == 1);
    QSCompany *company = [objects firstObject];
    XCTAssertTrue([company.name isEqualToString:@"new company"]);
    XCTAssertTrue([company.identifier isEqualToString:@"1"]);
}

- (void)testSaveChangesInRecord_missingProperty_setsPropertyToNil
{
    RLMRealm *realm = [self realmWithIdentifier:@"t24"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p24"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    objectRecord[@"name"] = nil;
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [realmAdapter prepareForImport];
    [realmAdapter saveChangesInRecords:@[objectRecord]];
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [realmAdapter didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(company.name);
}

- (void)testSaveChangesInRecord_missingRelationshipProperty_setsPropertyToNil
{
    RLMRealm *realm = [self realmWithIdentifier:@"t25"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSEmployee *employee = [self insertEmployeeWithValues:@{@"identifier": @"2", @"name": @"employee", @"company": company} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p25"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    [realmAdapter prepareForImport];
    [realmAdapter saveChangesInRecords:@[objectRecord]];
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [realmAdapter didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(employee.company);
}

- (void)testSaveChangesInRecord_missingToManyRelationshipProperty_doesNothing
{
    RLMRealm *realm = [self realmWithIdentifier:@"t31"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    [self insertEmployeeWithValues:@{@"identifier": @"2", @"name": @"employee", @"company": company} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p31"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *companyRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        for (CKRecord *record in uploadedRecords) {
            if ([record.recordID.recordName hasPrefix:@"QSCompany"]) {
                companyRecord = record;
            }
        }
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    companyRecord[@"employees"] = nil;
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [realmAdapter prepareForImport];
    [realmAdapter saveChangesInRecords:@[companyRecord]];
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [realmAdapter didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(company.employees);
}

- (void)testSaveChangesInRecords_ignoresPrimaryKeyField
{
    RLMRealm *realm = [self realmWithIdentifier:@"t34"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p34"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    objectRecord[@"identifier"] = @"2";
    objectRecord[@"name"] = @"name 2";
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [realmAdapter prepareForImport];
    [realmAdapter saveChangesInRecords:@[objectRecord]];
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [realmAdapter didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
    XCTAssertTrue([company.identifier isEqualToString:@"1"]);
}

- (void)testSync_multipleObjects_preservesRelationships
{
    RLMRealm *realm = [self realmWithIdentifier:@"t7"];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p7"]];
    
    CKRecord *companyRecord = [[CKRecord alloc] initWithRecordType:@"QSCompany" recordID:[[CKRecordID alloc] initWithRecordName:@"QSCompany.1"]];
    companyRecord[@"name"] = @"new company";
    companyRecord[@"identifier"] = @"1";
    
    CKRecord *employeeRecord = [[CKRecord alloc] initWithRecordType:@"QSEmployee" recordID:[[CKRecordID alloc] initWithRecordName:@"QSEmployee.2"]];
    employeeRecord[@"name"] = @"new employee";
    employeeRecord[@"identifier"] = @"2";
    employeeRecord[@"company"] = [[CKReference alloc] initWithRecordID:companyRecord.recordID action:CKReferenceActionNone];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [realmAdapter prepareForImport];
    [realmAdapter saveChangesInRecords:@[employeeRecord, companyRecord]];
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [realmAdapter didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    RLMResults *objects = [QSCompany allObjectsInRealm:realm];
    XCTAssertTrue(objects.count == 1);
    QSCompany *company = [objects firstObject];
    XCTAssertTrue([company.name isEqualToString:@"new company"]);
    XCTAssertTrue(company.employees.count == 1);
    if (company.employees.count) {
        QSEmployee *employee = (QSEmployee *)[company.employees firstObject];
        XCTAssertTrue([employee.name isEqualToString:@"new employee"]);
    }
}

- (void)testRecordsToUpload_changedObject_changesIncludeOnlyChangedProperties
{
    RLMRealm *realm = [self realmWithIdentifier:@"t8"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p8"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now change object
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    // Realm seems to delay delivery of notifications for deleted objects so we need to give it a chance to do so
    [self waitForHasChangesNotificationFromAdapter:realmAdapter];
    
    //Try to sync again
    [realmAdapter prepareForImport];
    NSArray *records = [realmAdapter recordsToUploadWithLimit:10];
    [realmAdapter didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count > 0);
    CKRecord *record = [records firstObject];
    XCTAssertTrue([record[@"name"] isEqual:@"name 2"]);
    XCTAssertNil(record[@"sortIndex"]);
}

- (void)testHasRecordID_missingObject_returnsNO
{
    RLMRealm *realm = [self realmWithIdentifier:@"t9"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p9"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    company = nil;
    
    XCTAssertFalse([realmAdapter hasRecordID:[[CKRecordID alloc] initWithRecordName:@"missing"]]);
}

- (void)testHasRecordID_existingObject_returnsYES
{
    RLMRealm *realm = [self realmWithIdentifier:@"t10"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p10"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    company = nil;
    
    XCTAssertTrue([realmAdapter hasRecordID:objectRecord.recordID]);
}

- (void)testHasChanges_noChanges_returnsNO
{
    RLMRealm *realm = [self realmWithIdentifier:@"t11"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p11"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    company = nil;
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertFalse(realmAdapter.hasChanges);
}

- (void)testHasChanges_objectChanged_returnsYES
{
    RLMRealm *realm = [self realmWithIdentifier:@"t12"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p12"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertFalse(realmAdapter.hasChanges);
    
    //Now change object
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    [self waitForHasChangesNotificationFromAdapter:realmAdapter];
    
    XCTAssertTrue(realmAdapter.hasChanges);
}

- (void)testHasChanges_afterSuccessfulSync_returnsNO
{
    RLMRealm *realm = [self realmWithIdentifier:@"t13"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p13"]];
    
    [self syncAdapterAndWait:realmAdapter];
    
    XCTAssertFalse(realmAdapter.hasChanges);
    
    //Now change object
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    [self waitForHasChangesNotificationFromAdapter:realmAdapter];
    
    XCTAssertTrue(realmAdapter.hasChanges);
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertFalse(realmAdapter.hasChanges);
}

- (void)testInit_insertedObject_objectIsTracked
{
    RLMRealm *realm = [self realmWithIdentifier:@"t22"];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p22"]];
    
    [self syncAdapterAndWait:realmAdapter];
    
    //Insert object in context after both realm and change manager have already been created
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    [self waitForHasChangesNotificationFromAdapter:realmAdapter];
    [self syncAdapterAndWait:realmAdapter];
    
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    [self waitForHasChangesNotificationFromAdapter:realmAdapter];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    __block CKRecord *record = nil;
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        record = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(record);
    XCTAssertTrue([record[@"name"] isEqualToString:@"name 2"]);
}

- (void)testRecordsToUpload_partialUploadSuccess_stillReturnsPendingRecords
{
    RLMRealm *realm = [self realmWithIdentifier:@"t14"];
    //Insert object in context
    
    [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    [self insertCompanyWithValues:@{@"identifier": @"2", @"name": @"company2", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p14"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    //Sync
    [realmAdapter prepareForImport];
    NSArray *recordsToUpload = [realmAdapter recordsToUploadWithLimit:1000];
    [realmAdapter didUploadRecords:@[recordsToUpload.firstObject]];
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [realmAdapter didFinishImportWithError:error];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSArray *recordsToUploadAfterSync = [realmAdapter recordsToUploadWithLimit:1000];
    
    XCTAssertTrue(recordsToUpload.count == 2);
    XCTAssertTrue(recordsToUploadAfterSync.count == 1);
}

- (void)testRecordsToUpload_doesNotIncludeObjectsWithOnlyToManyRelationshipChanges
{
    RLMRealm *realm = [self realmWithIdentifier:@"t15"];
    //Insert objects in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSEmployee *employee1 = [self insertEmployeeWithValues:@{@"identifier": @"e1", @"name": @"employee1"} inRealm:realm];
    QSEmployee *employee2 = [self insertEmployeeWithValues:@{@"identifier": @"e2", @"name": @"employee2"} inRealm:realm];
    
    
    //Create change manager and sync
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p15"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now change to-many relationship
    [realm beginWriteTransaction];
    employee1.company = company;
    employee2.company = company;
    [realm commitWriteTransaction];
    
    [self waitForHasChangesNotificationFromAdapter:realmAdapter];
    
    //Try to sync again and check that we don't get a record for the company object
    [realmAdapter prepareForImport];
    NSArray *records = [realmAdapter recordsToUploadWithLimit:10];
    [realmAdapter didFinishImportWithError:nil];
    
    CKRecord *companyRecord = nil;
    NSMutableSet *employeeRecords = [NSMutableSet set];
    for (CKRecord *record in records) {
        if ([record.recordType isEqualToString:@"QSCompany"]) {
            companyRecord = record;
        } else if ([record.recordType isEqualToString:@"QSEmployee"]) {
            [employeeRecords addObject:record];
        }
    }
    XCTAssertTrue(records.count == 2);
    XCTAssertTrue(employeeRecords.count == 2);
    XCTAssertNil(companyRecord);
}

- (void)testRecordsToUpload_whenRecordWasDownloadedForObject_usesCorrectRecordVersion
{
    RLMRealm *realm = [self realmWithIdentifier:@"t23"];
    //Create change manager and sync
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p23"]];
    
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
    [realmAdapter prepareForImport];
    [realmAdapter saveChangesInRecords:@[record]];
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [realmAdapter didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [realm refresh];
    
    // Now change object so it produces a record to upload
    
    QSCompany *company = [[QSCompany allObjectsInRealm:realm] firstObject];
    
    [realm beginWriteTransaction];
    company.name = @"another name";
    [realm commitWriteTransaction];
    
    [self waitForHasChangesNotificationFromAdapter:realmAdapter];
    
    // Sync
    [realmAdapter prepareForImport];
    NSArray *records = [realmAdapter recordsToUploadWithLimit:10];
    [realmAdapter didFinishImportWithError:nil];
    
    CKRecord *uploadedRecord = [records firstObject];
    XCTAssertEqual(uploadedRecord.recordChangeTag, recordChangeTag);
}

- (void)testRecordsToUpload_doesNotIncludePrimaryKey
{
    RLMRealm *realm = [self realmWithIdentifier:@"t32"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p32"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now change object
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    // Realm seems to delay delivery of notifications for deleted objects so we need to give it a chance to do so
    [self waitForHasChangesNotificationFromAdapter:realmAdapter];
    
    //Try to sync again
    [realmAdapter prepareForImport];
    NSArray *records = [realmAdapter recordsToUploadWithLimit:10];
    [realmAdapter didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count > 0);
    CKRecord *record = [records firstObject];
    XCTAssertNil(record[@"identifier"]);
}

#pragma mark - CKAsset

- (void)testRecordToUpload_dataProperty_uploadedAsAsset
{
    RLMRealm *realm = [self realmWithIdentifier:@"t40"];
    //Insert object in context
    [self insertEmployeeWithValues:@{@"identifier": @"e1", @"name": @"employee1", @"photo": [NSData data]} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p40"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    RLMRealm *realm = [self realmWithIdentifier:@"t44"];
    //Insert object in context
    [self insertEmployeeWithValues:@{@"identifier": @"e1", @"name": @"employee1", @"photo": [NSData data]} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p44"]];
    realmAdapter.forceDataTypeInsteadOfAsset = YES;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSData *photo = objectRecord[@"photo"];
    XCTAssertTrue([photo isKindOfClass:[NSData class]]);
}

- (void)testRecordToUpload_dataPropertyNil_nilsProperty
{
    RLMRealm *realm = [self realmWithIdentifier:@"t41"];
    //Insert object in context
    QSEmployee *employee = [self insertEmployeeWithValues:@{@"identifier": @"e1", @"name": @"employee1", @"photo": [NSData data]} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p41"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    [realm transactionWithBlock:^{
        employee.photo = nil;
    }];

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    CKAsset *asset = objectRecord[@"photo"];
    XCTAssertNil(asset);
}


- (void)testSaveChangesInRecord_assetProperty_updatesData
{
    RLMRealm *realm = [self realmWithIdentifier:@"t42"];
    //Insert object in context
    QSEmployee *employee = [self insertEmployeeWithValues:@{@"identifier": @"e1", @"name": @"employee1"} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p42"]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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

    [self fullySyncAdapter:realmAdapter downloadedRecords:@[objectRecord] deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];

    XCTAssertNotNil(employee.photo);
    XCTAssertEqual([employee.photo length], 8);
}

- (void)testSaveChangesInRecord_assetPropertyNil_nilsData
{
    RLMRealm *realm = [self realmWithIdentifier:@"t43"];
    //Insert object in context
    QSEmployee *employee = [self insertEmployeeWithValues:@{@"identifier": @"e1", @"name": @"employee1", @"photo": [NSData data]} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p43"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    objectRecord[@"photo"] = nil;
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter downloadedRecords:@[objectRecord] deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(employee.photo);
}

#pragma mark - Unique objects

- (void)testSaveChangesInRecord_existingUniqueObject_updatesObject
{
    RLMRealm *realm = [self realmWithIdentifier:@"t16"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p16"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    objectRecord[@"name"] = @"name 2";
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [realmAdapter prepareForImport];
    [realmAdapter saveChangesInRecords:@[objectRecord]];
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [realmAdapter didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
}

- (void)testRecordsToUpload_uniqueObjectsWithSameID_mapsObjectsToSameRecord
{
    RLMRealm *realm = [self realmWithIdentifier:@"t17"];
    
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p17"]];
    
    //Insert object in second realm using same identifier
    RLMRealm *realm2 = [self realmWithIdentifier:@"t17-2"];
    
    [self insertCompanyWithValues:@{@"identifier": company.identifier, @"name": @"company1", @"sortIndex": @1} inRealm:realm2];
    
    //Second change manager
    QSRealmAdapter *realmAdapter2 = [self realmAdapterWithTarget:realm2.configuration
                                                                  persistence:[self persistenceConfigurationWithIdentifier:@"p17-2"]];
    
    [realmAdapter prepareForImport];
    NSArray *records = [realmAdapter recordsToUploadWithLimit:10];
    [realmAdapter didFinishImportWithError:nil];
    
    [realmAdapter2 prepareForImport];
    NSArray *records2 = [realmAdapter2 recordsToUploadWithLimit:10];
    [realmAdapter2 didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count == 1);
    XCTAssertTrue(records2.count == 1);
    
    CKRecord *record = [records firstObject];
    CKRecord *record2 = [records2 firstObject];
    
    XCTAssertTrue([record.recordID.recordName isEqualToString:record2.recordID.recordName]);
}

- (void)testSync_uniqueObjectsWithSameID_updatesObjectCorrectly
{
    RLMRealm *realm = [self realmWithIdentifier:@"t18"];
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p18"]];
    
    RLMRealm *realm2 = [self realmWithIdentifier:@"t18-2"];
    
    QSCompany *company2 = [self insertCompanyWithValues:@{@"identifier": company.identifier, @"name": @"company2", @"sortIndex": @2} inRealm:realm2];
    
    QSRealmAdapter *realmAdapter2 = [self realmAdapterWithTarget:realm2.configuration
                                                                  persistence:[self persistenceConfigurationWithIdentifier:@"p18-2"]];
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncAdapter:realmAdapter2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([company2.name isEqualToString:@"company1"]);
}

#pragma mark - Merge policies

- (void)testSync_serverMergePolicy_prioritizesDownloadedChanges
{
    RLMRealm *realm = [self realmWithIdentifier:@"t19"];
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p19"]];
    
    RLMRealm *realm2 = [self realmWithIdentifier:@"t19-2"];
    
    QSCompany *company2 = [self insertCompanyWithValues:@{@"identifier": company.identifier, @"name": @"company2", @"sortIndex": @2} inRealm:realm2];
    
    QSRealmAdapter *realmAdapter2 = [self realmAdapterWithTarget:realm2.configuration
                                                                  persistence:[self persistenceConfigurationWithIdentifier:@"p19-2"]];
    realmAdapter2.mergePolicy = QSModelAdapterMergePolicyServer;
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncAdapter:realmAdapter2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([company2.name isEqualToString:@"company1"]);
}

- (void)testSync_clientMergePolicy_prioritizesLocalChanges
{
    RLMRealm *realm = [self realmWithIdentifier:@"t20"];
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p20"]];
    
    RLMRealm *realm2 = [self realmWithIdentifier:@"t20-2"];
    
    QSCompany *company2 = [self insertCompanyWithValues:@{@"identifier": company.identifier, @"name": @"company2", @"sortIndex": @2} inRealm:realm2];
    
    QSRealmAdapter *realmAdapter2 = [self realmAdapterWithTarget:realm2.configuration
                                                                  persistence:[self persistenceConfigurationWithIdentifier:@"p20-2"]];
    realmAdapter2.mergePolicy = QSModelAdapterMergePolicyClient;
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncAdapter:realmAdapter2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([company2.name isEqualToString:@"company2"]);
}

- (void)testSync_customMergePolicy_callsDelegateForResolution
{
    RLMRealm *realm = [self realmWithIdentifier:@"t21"];
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p21"]];
    
    RLMRealm *realm2 = [self realmWithIdentifier:@"t21-2"];
    
    QSCompany *company2 = [self insertCompanyWithValues:@{@"identifier": company.identifier, @"name": @"company2", @"sortIndex": @2} inRealm:realm2];
    
    QSRealmAdapter *realmAdapter2 = [self realmAdapterWithTarget:realm2.configuration
                                                                  persistence:[self persistenceConfigurationWithIdentifier:@"p21-2"]];
    realmAdapter2.mergePolicy = QSModelAdapterMergePolicyCustom;
    realmAdapter2.delegate = self;
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    __block BOOL calledCustomMergePolicyMethod = NO;
    self.customMergePolicyBlock = ^(QSRealmAdapter *realmAdapter, NSDictionary *changes, RLMObject *object) {
        if (realmAdapter == realmAdapter2 && [object isKindOfClass:[QSCompany class]] && [[changes objectForKey:@"name"] isEqualToString:@"company1"]) {
            calledCustomMergePolicyMethod = YES;
            [object setValue:@"company3" forKey:@"name"];
        }
    };
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncAdapter:realmAdapter2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue(calledCustomMergePolicyMethod);
    XCTAssertTrue([company2.name isEqualToString:@"company3"]);
}

#pragma mark - Sharing

- (void)testRecordForObjectWithIdentifier_noObject_returnsNil
{
    RLMRealm *realm = [self realmWithIdentifier:@"t50"];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p50"]];
    
    CKRecord *record = [realmAdapter recordForObject:nil];
    XCTAssertNil(record);
}

- (void)testRecordForObjectWithIdentifier_existingObject_returnsRecord
{
    RLMRealm *realm = [self realmWithIdentifier:@"t51"];
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p51"]];
    
    CKRecord *record = [realmAdapter recordForObject:company];
    XCTAssertNotNil(record);
    XCTAssertTrue([record.recordID.recordName hasPrefix:@"QSCompany"]);
}

- (void)testShareForObjectWithIdentifier_noShare_returnsNil
{
    RLMRealm *realm = [self realmWithIdentifier:@"t52"];
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p52"]];
    
    CKShare *share = [realmAdapter shareForObject:company];
    XCTAssertNil(share);
}

- (void)testShareForObjectWithIdentifier_saveShareCalled_returnsShare
{
    RLMRealm *realm = [self realmWithIdentifier:@"t53"];
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p53"]];
    
    CKRecord *record = [realmAdapter recordForObject:company];
    CKShare *share = [[CKShare alloc] initWithRootRecord:record];
    
    [realmAdapter saveShare:share forObject:company];
    
    CKShare *share2 = [realmAdapter shareForObject:company];
    XCTAssertNotNil(share2);
}

- (void)testShareForObjectWithIdentifier_shareDeleted_returnsNil
{
    RLMRealm *realm = [self realmWithIdentifier:@"t54"];
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p54"]];
    
    CKRecord *record = [realmAdapter recordForObject:company];
    CKShare *share = [[CKShare alloc] initWithRootRecord:record];
    
    [realmAdapter saveShare:share forObject:company];
    
    [realmAdapter deleteShareForObject:company];
    CKShare *share2 = [realmAdapter shareForObject:company];
    XCTAssertNil(share2);
}

- (void)testSaveChangesInRecords_includesShare_savesObjectAndShare
{
    RLMRealm *realm = [self realmWithIdentifier:@"t55"];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p55"]];
    
    CKRecord *companyRecord = [[CKRecord alloc] initWithRecordType:@"QSCompany" recordID:[[CKRecordID alloc] initWithRecordName:@"QSCompany.com1"]];
    companyRecord[@"name"] = @"new company";
    
    CKShare *shareRecord = [[CKShare alloc] initWithRootRecord:companyRecord shareID:[[CKRecordID alloc] initWithRecordName:@"QSShare.forCompany"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    [self fullySyncAdapter:realmAdapter downloadedRecords:@[companyRecord, shareRecord] deletedRecordIDs:@[] completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    QSCompany *company = [[QSCompany allObjectsInRealm:realm] firstObject];
    CKShare *share = [realmAdapter shareForObject:company];
    
    XCTAssertNotNil(company);
    XCTAssertNotNil(share);
    XCTAssertTrue([company.name isEqualToString:@"new company"]);
    XCTAssertTrue([share.recordID.recordName isEqualToString:@"QSShare.forCompany"]);
}

- (void)testDeleteRecordsWithIDs_containsShare_deletesShare
{
    RLMRealm *realm = [self realmWithIdentifier:@"t56"];
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p56"]];
    
    CKRecord *record = [realmAdapter recordForObject:company];
    CKRecordID *shareID = [[CKRecordID alloc] initWithRecordName:@"CKShare.identifier" zoneID:record.recordID.zoneID];
    CKShare *share = [[CKShare alloc] initWithRootRecord:record shareID:shareID];
    
    [realmAdapter saveShare:share forObject:company];
    
    CKShare *savedShare = [realmAdapter shareForObject:company];
    XCTAssertNotNil(savedShare);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    [self fullySyncAdapter:realmAdapter downloadedRecords:@[] deletedRecordIDs:@[shareID] completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    CKShare *updatedShare = [realmAdapter shareForObject:company];
    XCTAssertNil(updatedShare);
}

- (void)testRecordsToUpload_includesAnyParentRecordsInBatch
{
    RLMRealm *realm = [self realmWithIdentifier:@"t57"];
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"com1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    [self insertEmployeeWithValues:@{@"identifier": @"em1", @"name": @"employee1", @"sortIndex": @1, @"company": company} inRealm:realm];
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                     persistence:[self persistenceConfigurationWithIdentifier:@"p57"]];
    
    [realmAdapter prepareForImport];
    NSArray *records = [realmAdapter recordsToUploadWithLimit:1];
    [realmAdapter didFinishImportWithError:nil];
    
    XCTAssertEqual(records.count, 2);
    BOOL includesCompany = NO;
    BOOL includesEmployee = NO;
    for (CKRecord *record in records) {
        if ([record.recordID.recordName containsString:@"com1"]) {
            includesCompany = YES;
        }
        if ([record.recordID.recordName containsString:@"em1"]) {
            includesEmployee = YES;
        }
    }
}


#pragma  mark - Updating parent relationship

- (void)testRecordsToUpdateParentRelationshipsForRoot_returnsRecords
{
    RLMRealm *realm = [self realmWithIdentifier:@"t60"];
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"com1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSCompany *company2 = [self insertCompanyWithValues:@{@"identifier": @"com2", @"name": @"company2", @"sortIndex": @2} inRealm:realm];
    [self insertEmployeeWithValues:@{@"identifier": @"emp1", @"name": @"employee1", @"company": company} inRealm:realm];
    [self insertEmployeeWithValues:@{@"identifier": @"emp2", @"name": @"employee2", @"company": company} inRealm:realm];
    [self insertEmployeeWithValues:@{@"identifier": @"emp3", @"name": @"employee3", @"company": company2} inRealm:realm];
    [self insertEmployeeWithValues:@{@"identifier": @"emp4", @"name": @"employee4", @"company": company2} inRealm:realm];
    
    QSRealmAdapter *realmAdapter = [self realmAdapterWithTarget:realm.configuration
                                                    persistence:[self persistenceConfigurationWithIdentifier:@"p60"]];
    
    NSArray<CKRecord *> *records = [realmAdapter recordsToUpdateParentRelationshipsForRoot:company];
    
    XCTAssertEqual(records.count, 3);
    for (CKRecord *record in records) {
        XCTAssertTrue([record.recordID.recordName containsString:@"com1"] ||
                      [record.recordID.recordName containsString:@"emp1"] ||
                      [record.recordID.recordName containsString:@"emp2"]);
    }
}

#pragma mark - 0.6.0

- (void)testOldToken_preserved
{
    RLMRealm *realm = [self realmWithIdentifier:@"t70"];
    
    // Delete any leftover data
    QSCloudKitSynchronizer *synchronizer = [QSCloudKitSynchronizer cloudKitPrivateSynchronizerWithContainerName:@"container" realmConfiguration:realm.configuration];
    QSRealmAdapter *adapter = synchronizer.modelAdapters.firstObject;
    NSFileManager *manager = [NSFileManager defaultManager];
    RLMRealmConfiguration *config = adapter.persistenceConfiguration;
    NSArray<NSURL *> *realmFileURLs = @[
                                        config.fileURL,
                                        [config.fileURL URLByAppendingPathExtension:@"lock"],
                                        [config.fileURL URLByAppendingPathExtension:@"note"],
                                        [config.fileURL URLByAppendingPathExtension:@"management"]
                                        ];
    for (NSURL *URL in realmFileURLs) {
        NSError *error = nil;
        [manager removeItemAtURL:URL error:&error];
    }
    
    // Test
    NSData *data = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"serverChangeToken.AQAAAWPa1DUC" withExtension:@""]];
    CKServerChangeToken *token = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"containerQSCloudKitFetchChangesServerTokenKey"];
    
    QSCloudKitSynchronizer *synchronizer2 = [QSCloudKitSynchronizer cloudKitPrivateSynchronizerWithContainerName:@"container" realmConfiguration:realm.configuration];
    CKServerChangeToken *adapterToken = synchronizer2.modelAdapters.firstObject.serverChangeToken;
    
    XCTAssertNotNil(token);
    XCTAssertTrue([adapterToken isEqual:token]);
    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:@"containerQSCloudKitFetchChangesServerTokenKey"]);
}

#pragma mark - Utilities

- (RLMRealm *)realmWithIdentifier:(NSString *)identifier
{
    RLMRealmConfiguration *configuration = [[RLMRealmConfiguration alloc] init];
    configuration.schemaVersion = 1;
    configuration.inMemoryIdentifier = identifier;
    configuration.objectClasses = @[[QSCompany class], [QSEmployee class]];
    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:nil];
    return realm;
}

- (RLMRealmConfiguration *)persistenceConfigurationWithIdentifier:(NSString *)identifier
{
    RLMRealmConfiguration *configuration = [QSRealmAdapter defaultPersistenceConfiguration];
    configuration.inMemoryIdentifier = identifier;
    return configuration;
}

- (void)waitForHasChangesNotificationFromAdapter:(QSRealmAdapter *)realmAdapter
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Has changes notification arrived"];
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:QSModelAdapterHasChangesNotification object:realmAdapter queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

- (void)syncAdapterAndWait:(id<QSModelAdapter>)realmAdapter
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncAdapter:realmAdapter completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (QSCompany *)insertCompanyWithValues:(NSDictionary *)values inRealm:(RLMRealm *)realm
{
    QSCompany *company = [[QSCompany alloc] initWithValue:values];
    
    [realm beginWriteTransaction];
    [realm addObject:company];
    [realm commitWriteTransaction];
    
    return company;
}

- (QSEmployee *)insertEmployeeWithValues:(NSDictionary *)values inRealm:(RLMRealm *)realm
{
    QSEmployee *employee = [[QSEmployee alloc] initWithValue:values];
    
    [realm beginWriteTransaction];
    [realm addObject:employee];
    [realm commitWriteTransaction];
    
    return employee;
}

- (QSRealmAdapter *)realmAdapterWithTarget:(RLMRealmConfiguration *)targetConfiguration persistence:(RLMRealmConfiguration *)persistenceConfiguration
{
    QSRealmAdapter *realmAdapter = [[QSRealmAdapter alloc] initWithPersistenceRealmConfiguration:persistenceConfiguration targetRealmConfiguration:targetConfiguration recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"]];
    
    return realmAdapter;
}

- (void)fullySyncAdapter:(id<QSModelAdapter>)realmAdapter completion:(void(^)(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error))completion
{
    [realmAdapter prepareForImport];
    NSArray *recordsToUpload = [realmAdapter recordsToUploadWithLimit:1000];
    NSArray *recordIDsToDelete = [realmAdapter recordIDsMarkedForDeletionWithLimit:1000];
    [realmAdapter didUploadRecords:recordsToUpload];
    [realmAdapter didDeleteRecordIDs:recordIDsToDelete];
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        [realmAdapter didFinishImportWithError:nil];
        completion(recordsToUpload, recordIDsToDelete, error);
    }];
}

- (void)fullySyncAdapter:(id<QSModelAdapter>)realmAdapter downloadedRecords:(NSArray *)records deletedRecordIDs:(NSArray *)recordIDs completion:(void(^)(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error))completion
{
    [realmAdapter prepareForImport];
    [realmAdapter saveChangesInRecords:records];
    [realmAdapter deleteRecordsWithIDs:recordIDs];
    
    [realmAdapter persistImportedChangesWithCompletion:^(NSError *error) {
        NSArray *recordsToUpload = nil;
        NSArray *recordIDsToDelete = nil;
        if (!error) {
            recordsToUpload = [realmAdapter recordsToUploadWithLimit:1000];
            recordIDsToDelete = [realmAdapter recordIDsMarkedForDeletionWithLimit:1000];
            [realmAdapter didUploadRecords:recordsToUpload];
            [realmAdapter didDeleteRecordIDs:recordIDsToDelete];
        }
        
        [realmAdapter didFinishImportWithError:error];
        completion(recordsToUpload, recordIDsToDelete, error);
    }];
}

- (void)realmAdapter:(QSRealmAdapter *)realmAdapter gotChanges:(NSDictionary *)changeDictionary forObject:(RLMObject *)object
{
    self.customMergePolicyBlock(realmAdapter, changeDictionary, object);
}

@end
