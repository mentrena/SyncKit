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
#import "QSEmployee2.h"
#import "QSCompany2.h"

@interface QSCoreDataChangeManagerTests : XCTestCase <QSCoreDataChangeManagerDelegate>

@property (nonatomic, strong) QSCoreDataStack *targetCoreDataStack;
@property (nonatomic, strong) QSCoreDataStack *coreDataStack;

@property (nonatomic, assign) BOOL didCallRequestContextSave;
@property (nonatomic, assign) BOOL didCallImportChanges;

@property (nonatomic, copy) void(^customMergePolicyBlock)(QSCoreDataChangeManager *changeManager, NSManagedObject *object, NSDictionary *changes);

@end

@implementation QSCoreDataChangeManagerTests

- (void)setUp {
    [super setUp];
    
    self.targetCoreDataStack = [self coreDataStackWithModelName:@"QSExample"];
    self.coreDataStack = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataChangeManager persistenceModel] storePath:nil dispatchImmediately:YES];
}

- (void)setUpModel2
{
    self.targetCoreDataStack = [self coreDataStackWithModelName:@"QSExample2"];
}

- (QSCoreDataStack *)coreDataStackWithModelName:(NSString *)modelName
{
    NSURL *modelURL = [[NSBundle bundleForClass:[self class]] URLForResource:modelName withExtension:@"momd"];
    QSCoreDataStack *stack = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL] storePath:nil dispatchImmediately:YES];
    return stack;
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
        [changeManager.targetContext performBlockAndWait:^{
            [changeManager.targetContext save:nil];
        }];
        completion(nil);
    }];
}

- (void)changeManager:(QSCoreDataChangeManager *)changeManager gotChanges:(NSDictionary *)changeDictionary forObject:(NSManagedObject *)object
{
    if (self.customMergePolicyBlock) {
        self.customMergePolicyBlock(changeManager, object, changeDictionary);
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

- (void)testRecordsToUpload_onlyIncludesToOneRelationships
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    QSEmployee *employee = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSEmployee class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    employee.name = @"employee 1";
    employee.company = company;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
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
    
    XCTAssertNil(companyRecord[@"employees"]);
    XCTAssertNotNil(employeeRecord[@"company"]);
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
    [changeManager deleteRecordsWithIDs:@[objectRecord.recordID]];
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
    [changeManager saveChangesInRecords:@[objectRecord]];
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
    
    CKRecord *objectRecord = [[CKRecord alloc] initWithRecordType:@"QSCompany" recordID:[[CKRecordID alloc] initWithRecordName:@"1"]];
    objectRecord[@"name"] = @"new company";
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"merged changes"];
    
    //Start sync and delete object
    [changeManager prepareForImport];
    [changeManager saveChangesInRecords:@[objectRecord]];
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

- (void)testSaveChangesInRecord_missingProperty_setsPropertyToNil
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
    
    [self.targetCoreDataStack.managedObjectContext refreshObject:company mergeChanges:NO];
    XCTAssertNil(company.name);
}

- (void)testSaveChangesInRecord_missingRelationshipProperty_setsPropertyToNil
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    QSEmployee *employee = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSEmployee class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    employee.name = @"employee 1";
    employee.company = company;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
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
    
    [self.targetCoreDataStack.managedObjectContext refreshObject:employee mergeChanges:NO];
    XCTAssertNil(employee.company);
}

- (void)testSaveChangesInRecord_missingToManyRelationshipProperty_doesNothing
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    QSEmployee *employee = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSEmployee class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    employee.name = @"employee 1";
    employee.company = company;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block CKRecord *objectRecord = nil;
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
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
    [changeManager prepareForImport];
    [changeManager saveChangesInRecords:@[objectRecord]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [self.targetCoreDataStack.managedObjectContext refreshObject:company mergeChanges:NO];
    XCTAssertNotNil(company.employees);
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
    [changeManager saveChangesInRecords:@[employeeRecord, companyRecord]];
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

- (void)testHasChanges_afterSuccessfulSync_returnsNO
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    company.name = @"name 2";
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertFalse(changeManager.hasChanges);
}

- (void)testDeleteChangeTracking_deletesStore
{
    //Insert object in context
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    [changeManager deleteChangeTracking];
    
    XCTAssertNil(self.coreDataStack.managedObjectContext);
}

- (void)testRecordsToUpload_partialUploadSuccess_stillReturnsPendingRecords
{
    //Insert object in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"company 1";
    QSCompany *company2 = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company2.name = @"company 2";
    NSError *error = nil;
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
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
    //Insert objects in context
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSError *error = nil;
    
    QSEmployee *employee1 = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSEmployee class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    employee1.name = @"employee1";
    QSEmployee *employee2 = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSEmployee class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    employee1.name = @"employee2";
    
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
    //Create change manager and sync
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    //Now change to-many relationship
    company.employees = [NSSet setWithObjects:employee1, employee2, nil];
    [self.targetCoreDataStack.managedObjectContext save:&error];
    
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
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
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
    
    // Now change object so it produces a record to upload
    
    NSArray *objects = [self.targetCoreDataStack.managedObjectContext executeFetchRequestWithEntityName:@"QSCompany" error:nil];
    QSCompany *company = [objects firstObject];
    company.name = @"another name";
    [self.targetCoreDataStack.managedObjectContext save:nil];
    
    
    // Sync
    [changeManager prepareForImport];
    NSArray *records = [changeManager recordsToUploadWithLimit:10];
    [changeManager didFinishImportWithError:nil];
    
    CKRecord *uploadedRecord = [records firstObject];
    XCTAssertEqual(uploadedRecord.recordChangeTag, recordChangeTag);
}

#pragma mark - Unique objects

- (void)testSaveChangesInRecord_existingUniqueObject_updatesObject
{
    [self setUpModel2];
    
    //Insert object in context
    QSCompany2 *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany2 class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    company.identifier = [[NSUUID UUID] UUIDString];
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
    [changeManager saveChangesInRecords:@[objectRecord]];
    [changeManager persistImportedChangesWithCompletion:^(NSError *error) {
        [expectation2 fulfill];
    }];
    [changeManager didFinishImportWithError:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [self.targetCoreDataStack.managedObjectContext refreshObject:company mergeChanges:NO];
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
}

- (void)testRecordsToUpload_uniqueObjectsWithSameID_mapsObjectsToSameRecord
{
    [self setUpModel2];
    QSCoreDataStack *target2 = [self coreDataStackWithModelName:@"QSExample2"];
    QSCoreDataStack *persistence2 = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataChangeManager persistenceModel] storePath:nil dispatchImmediately:YES];
    
    //Insert object in context
    QSCompany2 *company = [self insertAndSaveObjectOfType:@"QSCompany2"
                                               properties:@{@"name": @"name 1",
                                                            @"identifier": [[NSUUID UUID] UUIDString]
                                                            }
                                              intoContext:self.targetCoreDataStack.managedObjectContext];
    
    //Insert object with same identifier in the other stack
    [self insertAndSaveObjectOfType:@"QSCompany2"
                         properties:@{@"name": @"name 2",
                                      @"identifier": company.identifier}
                        intoContext:target2.managedObjectContext];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    QSCoreDataChangeManager *changeManager2 = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:persistence2 targetContext:target2.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    //Get records to upload
    
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
    [self setUpModel2];
    QSCoreDataStack *target2 = [self coreDataStackWithModelName:@"QSExample2"];
    QSCoreDataStack *persistence2 = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataChangeManager persistenceModel] storePath:nil dispatchImmediately:YES];
    
    //Insert object in context
    QSCompany2 *company = [self insertAndSaveObjectOfType:@"QSCompany2"
                                               properties:@{@"name": @"name 1",
                                                            @"identifier": [[NSUUID UUID] UUIDString]
                                                            }
                                              intoContext:self.targetCoreDataStack.managedObjectContext];
    
    QSCompany2 *company2 = [self insertAndSaveObjectOfType:@"QSCompany2"
                                                properties:@{@"name": @"name 2",
                                                             @"identifier": company.identifier}
                                               intoContext:target2.managedObjectContext];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    QSCoreDataChangeManager *changeManager2 = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:persistence2 targetContext:target2.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncChangeManager:changeManager2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [target2.managedObjectContext refreshObject:company2 mergeChanges:NO];
    
    XCTAssertTrue([company2.name isEqualToString:@"name 1"]);
}

- (void)testRecordsToUpload_doesNotIncludePrimaryKey
{
    [self setUpModel2];
    
    //Insert object in context
    QSCompany2 *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany2 class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    company.identifier = [[NSUUID UUID] UUIDString];
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
    
    XCTAssertNil(objectRecord[@"identifier"]);
    XCTAssertNotNil(objectRecord[@"name"]);
}

- (void)testSaveChangesInRecords_ignoresPrimaryKeyField
{
    [self setUpModel2];
    
    //Insert object in context
    QSCompany2 *company = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([QSCompany2 class]) inManagedObjectContext:self.targetCoreDataStack.managedObjectContext];
    company.name = @"name 1";
    NSString *identifier = [[NSUUID UUID] UUIDString];
    company.identifier = identifier;
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
    
    objectRecord[@"identifier"] = @"fake identifier";
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
    
    [self.targetCoreDataStack.managedObjectContext refreshObject:company mergeChanges:NO];
    XCTAssertTrue([company.name isEqualToString:@"name 2"]);
    XCTAssertEqual(company.identifier, identifier);
}

#pragma mark - Merge policies

- (void)testSync_serverMergePolicy_prioritizesDownloadedChanges
{
    [self setUpModel2];
    QSCoreDataStack *target2 = [self coreDataStackWithModelName:@"QSExample2"];
    QSCoreDataStack *persistence2 = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataChangeManager persistenceModel] storePath:nil dispatchImmediately:YES];
    
    //Insert object in context
    QSCompany2 *company = [self insertAndSaveObjectOfType:@"QSCompany2"
                                               properties:@{@"name": @"name 1",
                                                            @"identifier": [[NSUUID UUID] UUIDString]
                                                            }
                                              intoContext:self.targetCoreDataStack.managedObjectContext];
    
    QSCompany2 *company2 = [self insertAndSaveObjectOfType:@"QSCompany2"
                                                properties:@{@"name": @"name 2",
                                                             @"identifier": company.identifier}
                                               intoContext:target2.managedObjectContext];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    QSCoreDataChangeManager *changeManager2 = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:persistence2 targetContext:target2.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncChangeManager:changeManager2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [target2.managedObjectContext refreshObject:company2 mergeChanges:NO];
    
    XCTAssertTrue([company2.name isEqualToString:@"name 1"]);
}

- (void)testSync_clientMergePolicy_prioritizesLocalChanges
{
    [self setUpModel2];
    QSCoreDataStack *target2 = [self coreDataStackWithModelName:@"QSExample2"];
    QSCoreDataStack *persistence2 = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataChangeManager persistenceModel] storePath:nil dispatchImmediately:YES];
    
    //Insert object in context
    QSCompany2 *company = [self insertAndSaveObjectOfType:@"QSCompany2"
                                               properties:@{@"name": @"name 1",
                                                            @"identifier": [[NSUUID UUID] UUIDString]
                                                            }
                                              intoContext:self.targetCoreDataStack.managedObjectContext];
    
    QSCompany2 *company2 = [self insertAndSaveObjectOfType:@"QSCompany2"
                                                properties:@{@"name": @"name 2",
                                                             @"identifier": company.identifier}
                                               intoContext:target2.managedObjectContext];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    QSCoreDataChangeManager *changeManager2 = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:persistence2 targetContext:target2.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    changeManager2.mergePolicy = QSCloudKitSynchronizerMergePolicyClient;
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncChangeManager:changeManager2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [target2.managedObjectContext refreshObject:company2 mergeChanges:NO];
    
    XCTAssertTrue([company2.name isEqualToString:@"name 2"]);
}

- (void)testSync_customMergePolicy_callsDelegateForResolution
{
    [self setUpModel2];
    QSCoreDataStack *target2 = [self coreDataStackWithModelName:@"QSExample2"];
    QSCoreDataStack *persistence2 = [[QSCoreDataStack alloc] initWithStoreType:NSInMemoryStoreType model:[QSCoreDataChangeManager persistenceModel] storePath:nil dispatchImmediately:YES];
    
    //Insert object in context
    QSCompany2 *company = [self insertAndSaveObjectOfType:@"QSCompany2"
                                               properties:@{@"name": @"name 1",
                                                            @"identifier": [[NSUUID UUID] UUIDString]
                                                            }
                                              intoContext:self.targetCoreDataStack.managedObjectContext];
    
    QSCompany2 *company2 = [self insertAndSaveObjectOfType:@"QSCompany2"
                                                properties:@{@"name": @"name 2",
                                                             @"identifier": company.identifier}
                                               intoContext:target2.managedObjectContext];
    
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:self.coreDataStack targetContext:self.targetCoreDataStack.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    QSCoreDataChangeManager *changeManager2 = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:persistence2 targetContext:target2.managedObjectContext recordZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"] delegate:self];
    changeManager2.mergePolicy = QSCloudKitSynchronizerMergePolicyCustom;
    
    //Get records to upload
    XCTestExpectation *expectation = [self expectationWithDescription:@"synced"];
    __block BOOL calledCustomMergePolicyMethod = NO;
    self.customMergePolicyBlock = ^(QSCoreDataChangeManager *changeManager, NSManagedObject *object, NSDictionary *changes) {
        if (changeManager == changeManager2 && [object isKindOfClass:[QSCompany2 class]] && [[changes objectForKey:@"name"] isEqualToString:@"name 1"]) {
            calledCustomMergePolicyMethod = YES;
            [object setValue:@"name 3" forKey:@"name"];
        }
    };
    
    [self fullySyncChangeManager:changeManager completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
        
        [self fullySyncChangeManager:changeManager2 downloadedRecords:uploadedRecords deletedRecordIDs:nil completion:^(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error) {
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [target2.managedObjectContext refreshObject:company2 mergeChanges:NO];
    
    XCTAssertTrue(calledCustomMergePolicyMethod);
    XCTAssertTrue([company2.name isEqualToString:@"name 3"]);
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

- (void)fullySyncChangeManager:(QSCoreDataChangeManager *)changeManager completion:(void(^)(NSArray *uploadedRecords, NSArray *deletedRecordIDs, NSError *error))completion
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

@end
