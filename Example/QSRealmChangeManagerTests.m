//
//  QSRealmChangeManagerTests.m
//  SyncKitRealm
//
//  Created by Manuel Entrena on 07/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "QSCompany.h"
#import "QSEmployee.h"
#import <Realm/Realm.h>
#import <SyncKit/QSRealmChangeManager.h>

@interface QSRealmChangeManagerTests : XCTestCase <QSRealmChangeManagerDelegate>

@property (nonatomic, copy) void(^customMergePolicyBlock)(QSRealmChangeManager *changeManager, NSDictionary *changes, RLMObject *object);

@end

@implementation QSRealmChangeManagerTests

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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p1"]];
    
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordsToUploadWithLimit:10];
    [changeManager didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count > 0, @"Expect one record to upload");
    CKRecord *record = [records firstObject];
    XCTAssertTrue([record[@"name"] isEqual:@"company1"], @"Name in record should be 'company1'");
}

- (void)testRecordsToUpload_changedObject_returnsRecordWithChanges
{
    RLMRealm *realm = [self realmWithIdentifier:@"t2"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p2"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now change object
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    // Realm seems to delay delivery of notifications for deleted objects so we need to give it a chance to do so
    [self waitForHasChangesNotificationFromChangeManager:changeManager];
    
    //Try to sync again
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordsToUploadWithLimit:10];
    [changeManager didFinishImportWithError:nil];
    
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p30"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    __block CKRecord *companyRecord = nil;
    __block CKRecord *employeeRecord = nil;
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p3"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordIDsMarkedForDeletionWithLimit:1000];
    [changeManager didFinishImportWithError:nil];
    
    XCTAssertTrue(records.count > 0);
    XCTAssertTrue([[[records firstObject] recordName] isEqualToString:@"QSCompany.1"]);
}

- (void)testDeleteRecordWithID_deletesCorrespondingObject
{
    RLMRealm *realm = [self realmWithIdentifier:@"t4"];
    // Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p4"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    company = nil;
    
    //Start sync and delete object
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    [self fullySyncChangeManager:changeManager downloadedRecords:@[] deletedRecordIDs:@[objectRecord.recordID] completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p5"]];
    
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
    [changeManager saveChangesInRecords:@[objectRecord]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
}

- (void)testSaveChangesInRecord_newObject_insertsObject
{
    RLMRealm *realm = [self realmWithIdentifier:@"t6"];
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p6"]];
    
    CKRecord *objectRecord = [[CKRecord alloc] initWithRecordType:@"QSCompany" recordID:[[CKRecordID alloc] initWithRecordName:@"QSCompany.1"]];
    objectRecord[@"name"] = @"new company";
    objectRecord[@"identifier"] = @"1";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [changeManager prepareForImport];
    [changeManager saveChangesInRecords:@[objectRecord]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p24"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    objectRecord[@"name"] = nil;
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [changeManager prepareForImport];
    [changeManager saveChangesInRecords:@[objectRecord]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(company.name);
}

- (void)testSaveChangesInRecord_missingRelationshipProperty_setsPropertyToNil
{
    RLMRealm *realm = [self realmWithIdentifier:@"t25"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSEmployee *employee = [self insertEmployeeWithValues:@{@"identifier": @"2", @"name": @"employee", @"company": company} inRealm:realm];
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p25"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    [changeManager prepareForImport];
    [changeManager saveChangesInRecords:@[objectRecord]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(employee.company);
}

- (void)testSaveChangesInRecord_missingToManyRelationshipProperty_doesNothing
{
    RLMRealm *realm = [self realmWithIdentifier:@"t31"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    [self insertEmployeeWithValues:@{@"identifier": @"2", @"name": @"employee", @"company": company} inRealm:realm];
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p31"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *companyRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    [changeManager prepareForImport];
    [changeManager saveChangesInRecords:@[companyRecord]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(company.employees);
}

- (void)testSaveChangesInRecords_ignoresPrimaryKeyField
{
    RLMRealm *realm = [self realmWithIdentifier:@"t34"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p34"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    objectRecord[@"identifier"] = @"2";
    objectRecord[@"name"] = @"name 2";
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [changeManager prepareForImport];
    [changeManager saveChangesInRecords:@[objectRecord]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
    XCTAssertTrue([company.identifier isEqualToString:@"1"]);
}

- (void)testSync_multipleObjects_preservesRelationships
{
    RLMRealm *realm = [self realmWithIdentifier:@"t7"];
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
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
    [changeManager prepareForImport];
    [changeManager saveChangesInRecords:@[employeeRecord, companyRecord]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p8"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now change object
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    // Realm seems to delay delivery of notifications for deleted objects so we need to give it a chance to do so
    [self waitForHasChangesNotificationFromChangeManager:changeManager];
    
    //Try to sync again
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordsToUploadWithLimit:10];
    [changeManager didFinishImportWithError:nil];
    
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p9"]];
    
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
    RLMRealm *realm = [self realmWithIdentifier:@"t10"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p10"]];
    
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
    RLMRealm *realm = [self realmWithIdentifier:@"t11"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p11"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    company = nil;
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertFalse(changeManager.hasChanges);
}

- (void)testHasChanges_objectChanged_returnsYES
{
    RLMRealm *realm = [self realmWithIdentifier:@"t12"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p12"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertFalse(changeManager.hasChanges);
    
    //Now change object
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    [self waitForHasChangesNotificationFromChangeManager:changeManager];
    
    XCTAssertTrue(changeManager.hasChanges);
}

- (void)testHasChanges_afterSuccessfulSync_returnsNO
{
    RLMRealm *realm = [self realmWithIdentifier:@"t13"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p13"]];
    
    [self syncChangeManagerAndWait:changeManager];
    
    XCTAssertFalse(changeManager.hasChanges);
    
    //Now change object
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    [self waitForHasChangesNotificationFromChangeManager:changeManager];
    
    XCTAssertTrue(changeManager.hasChanges);
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertFalse(changeManager.hasChanges);
}

- (void)testInit_insertedObject_objectIsTracked
{
    RLMRealm *realm = [self realmWithIdentifier:@"t22"];
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p22"]];
    
    [self syncChangeManagerAndWait:changeManager];
    
    //Insert object in context after both realm and change manager have already been created
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    [self waitForHasChangesNotificationFromChangeManager:changeManager];
    [self syncChangeManagerAndWait:changeManager];
    
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    [self waitForHasChangesNotificationFromChangeManager:changeManager];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    __block CKRecord *record = nil;
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p14"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    //Sync
    [changeManager prepareForImport];
    NSArray *recordsToUpload = [changeManager recordsToUploadWithLimit:1000];
    [changeManager didUploadRecords:@[recordsToUpload.firstObject]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [changeManager didFinishImportWithError:error];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSArray *recordsToUploadAfterSync = [changeManager recordsToUploadWithLimit:1000];
    
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
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p15"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now change to-many relationship
    [realm beginWriteTransaction];
    employee1.company = company;
    employee2.company = company;
    [realm commitWriteTransaction];
    
    [self waitForHasChangesNotificationFromChangeManager:changeManager];
    
    //Try to sync again and check that we don't get a record for the company object
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordsToUploadWithLimit:10];
    [changeManager didFinishImportWithError:nil];
    
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
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
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
    [changeManager prepareForImport];
    [changeManager saveChangesInRecords:@[record]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [realm refresh];
    
    // Now change object so it produces a record to upload
    
    QSCompany *company = [[QSCompany allObjectsInRealm:realm] firstObject];
    
    [realm beginWriteTransaction];
    company.name = @"another name";
    [realm commitWriteTransaction];
    
    [self waitForHasChangesNotificationFromChangeManager:changeManager];
    
    // Sync
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordsToUploadWithLimit:10];
    [changeManager didFinishImportWithError:nil];
    
    CKRecord *uploadedRecord = [records firstObject];
    XCTAssertEqual(uploadedRecord.recordChangeTag, recordChangeTag);
}

- (void)testRecordsToUpload_doesNotIncludePrimaryKey
{
    RLMRealm *realm = [self realmWithIdentifier:@"t32"];
    //Insert object in context
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": @"1", @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p32"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now change object
    [realm beginWriteTransaction];
    company.name = @"name 2";
    [realm commitWriteTransaction];
    
    // Realm seems to delay delivery of notifications for deleted objects so we need to give it a chance to do so
    [self waitForHasChangesNotificationFromChangeManager:changeManager];
    
    //Try to sync again
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordsToUploadWithLimit:10];
    [changeManager didFinishImportWithError:nil];
    
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p40"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p44"]];
    changeManager.forceDataTypeInsteadOfAsset = YES;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p41"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    [realm transactionWithBlock:^{
        employee.photo = nil;
    }];

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p42"]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;

    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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

    [self fullySyncChangeManager:changeManager downloadedRecords:@[objectRecord] deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p43"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        objectRecord = [uploadedRecords firstObject];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    objectRecord[@"photo"] = nil;
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager downloadedRecords:@[objectRecord] deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p16"]];
    
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
    [changeManager saveChangesInRecords:@[objectRecord]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
}

- (void)testRecordsToUpload_uniqueObjectsWithSameID_mapsObjectsToSameRecord
{
    RLMRealm *realm = [self realmWithIdentifier:@"t17"];
    
    QSCompany *company = [self insertCompanyWithValues:@{@"identifier": [[NSUUID UUID] UUIDString], @"name": @"company1", @"sortIndex": @1} inRealm:realm];
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p17"]];
    
    //Insert object in second realm using same identifier
    RLMRealm *realm2 = [self realmWithIdentifier:@"t17-2"];
    
    [self insertCompanyWithValues:@{@"identifier": company.identifier, @"name": @"company1", @"sortIndex": @1} inRealm:realm2];
    
    //Second change manager
    QSRealmChangeManager *changeManager2 = [self realmChangeManagerWithTarget:realm2.configuration
                                                                  persistence:[self persistenceConfigurationWithIdentifier:@"p17-2"]];
    
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordsToUploadWithLimit:10];
    [changeManager didFinishImportWithError:nil];
    
    [changeManager2 prepareForImport];
    NSArray *records2 = [changeManager2 recordsToUploadWithLimit:10];
    [changeManager2 didFinishImportWithError:nil];
    
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
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p18"]];
    
    RLMRealm *realm2 = [self realmWithIdentifier:@"t18-2"];
    
    QSCompany *company2 = [self insertCompanyWithValues:@{@"identifier": company.identifier, @"name": @"company2", @"sortIndex": @2} inRealm:realm2];
    
    QSRealmChangeManager *changeManager2 = [self realmChangeManagerWithTarget:realm2.configuration
                                                                  persistence:[self persistenceConfigurationWithIdentifier:@"p18-2"]];
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncChangeManager:changeManager2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p19"]];
    
    RLMRealm *realm2 = [self realmWithIdentifier:@"t19-2"];
    
    QSCompany *company2 = [self insertCompanyWithValues:@{@"identifier": company.identifier, @"name": @"company2", @"sortIndex": @2} inRealm:realm2];
    
    QSRealmChangeManager *changeManager2 = [self realmChangeManagerWithTarget:realm2.configuration
                                                                  persistence:[self persistenceConfigurationWithIdentifier:@"p19-2"]];
    changeManager2.mergePolicy = QSCloudKitSynchronizerMergePolicyServer;
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncChangeManager:changeManager2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p20"]];
    
    RLMRealm *realm2 = [self realmWithIdentifier:@"t20-2"];
    
    QSCompany *company2 = [self insertCompanyWithValues:@{@"identifier": company.identifier, @"name": @"company2", @"sortIndex": @2} inRealm:realm2];
    
    QSRealmChangeManager *changeManager2 = [self realmChangeManagerWithTarget:realm2.configuration
                                                                  persistence:[self persistenceConfigurationWithIdentifier:@"p20-2"]];
    changeManager2.mergePolicy = QSCloudKitSynchronizerMergePolicyClient;
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncChangeManager:changeManager2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    QSRealmChangeManager *changeManager = [self realmChangeManagerWithTarget:realm.configuration
                                                                 persistence:[self persistenceConfigurationWithIdentifier:@"p21"]];
    
    RLMRealm *realm2 = [self realmWithIdentifier:@"t21-2"];
    
    QSCompany *company2 = [self insertCompanyWithValues:@{@"identifier": company.identifier, @"name": @"company2", @"sortIndex": @2} inRealm:realm2];
    
    QSRealmChangeManager *changeManager2 = [self realmChangeManagerWithTarget:realm2.configuration
                                                                  persistence:[self persistenceConfigurationWithIdentifier:@"p21-2"]];
    changeManager2.mergePolicy = QSCloudKitSynchronizerMergePolicyCustom;
    changeManager2.delegate = self;
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    __block BOOL calledCustomMergePolicyMethod = NO;
    self.customMergePolicyBlock = ^(QSRealmChangeManager *changeManager, NSDictionary *changes, RLMObject *object) {
        if (changeManager == changeManager2 && [object isKindOfClass:[QSCompany class]] && [[changes objectForKey:@"name"] isEqualToString:@"company1"]) {
            calledCustomMergePolicyMethod = YES;
            [object setValue:@"company3" forKey:@"name"];
        }
    };
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncChangeManager:changeManager2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue(calledCustomMergePolicyMethod);
    XCTAssertTrue([company2.name isEqualToString:@"company3"]);
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
    RLMRealmConfiguration *configuration = [QSRealmChangeManager defaultPersistenceConfiguration];
    configuration.inMemoryIdentifier = identifier;
    return configuration;
}

- (void)waitForHasChangesNotificationFromChangeManager:(QSRealmChangeManager *)changeManager
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Has changes notification arrived"];
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:QSChangeManagerHasChangesNotification object:changeManager queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

- (void)syncChangeManagerAndWait:(id<QSChangeManager>)changeManager
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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

- (QSRealmChangeManager *)realmChangeManagerWithTarget:(RLMRealmConfiguration *)targetConfiguration persistence:(RLMRealmConfiguration *)persistenceConfiguration
{
    QSRealmChangeManager *changeManager = [[QSRealmChangeManager alloc] initWithPersistenceRealmConfiguration:persistenceConfiguration targetRealmConfiguration:targetConfiguration recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"]];
    
    return changeManager;
}

- (void)fullySyncChangeManager:(id<QSChangeManager>)changeManager completion:(void(^)(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error))completion
{
    [changeManager prepareForImport];
    NSArray *recordsToUpload = [changeManager recordsToUploadWithLimit:1000];
    NSArray *recordIDsToDelete = [changeManager recordIDsMarkedForDeletionWithLimit:1000];
    [changeManager didUploadRecords:recordsToUpload];
    [changeManager didDeleteRecordIDs:recordIDsToDelete];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [changeManager didFinishImportWithError:nil];
        completion(recordsToUpload, recordIDsToDelete, error);
    }];
}

- (void)fullySyncChangeManager:(id<QSChangeManager>)changeManager downloadedRecords:(NSArray *)records deletedRecordIDs:(NSArray *)recordIDs completion:(void(^)(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error))completion
{
    [changeManager prepareForImport];
    [changeManager saveChangesInRecords:records];
    [changeManager deleteRecordsWithIDs:recordIDs];
    
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        NSArray *recordsToUpload = nil;
        NSArray *recordIDsToDelete = nil;
        if (!error) {
            recordsToUpload = [changeManager recordsToUploadWithLimit:1000];
            recordIDsToDelete = [changeManager recordIDsMarkedForDeletionWithLimit:1000];
            [changeManager didUploadRecords:recordsToUpload];
            [changeManager didDeleteRecordIDs:recordIDsToDelete];
        }
        
        [changeManager didFinishImportWithError:error];
        completion(recordsToUpload, recordIDsToDelete, error);
    }];
}

- (void)changeManager:(QSRealmChangeManager *)changeManager gotChanges:(NSDictionary *)changeDictionary forObject:(RLMObject *)object
{
    self.customMergePolicyBlock(changeManager, changeDictionary, object);
}

@end
