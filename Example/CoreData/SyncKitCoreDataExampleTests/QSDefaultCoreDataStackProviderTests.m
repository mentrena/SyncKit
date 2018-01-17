//
//  QSDefaultCoreDataStackProviderTests.m
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 11/05/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <SyncKit/QSDefaultCoreDataStackProvider.h>
#import <SyncKit/QSCoreDataAdapter.h>
#import <CoreData/CoreData.h>

@interface QSDefaultCoreDataStackProviderTests : XCTestCase

@property (nonatomic, strong) QSDefaultCoreDataStackProvider *provider;

@end

@implementation QSDefaultCoreDataStackProviderTests

- (void)setUp {
    [super setUp];
    
    self.provider = [self providerWithID:@"provider1"];
}

- (void)tearDown {
    
    [self clearProviderDirectory:self.provider];
    self.provider = nil;
    
    [super tearDown];
}

- (QSDefaultCoreDataStackProvider *)providerWithID:(NSString *)identifier
{
    NSURL *modelURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"QSExample" withExtension:@"momd"];
    return [[QSDefaultCoreDataStackProvider alloc] initWithIdentifier:identifier storeType:NSSQLiteStoreType model:[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL]];
}

- (NSURL *)directoryForProviderWithIdentifier:(NSString *)identifier
{
    return [NSURL fileURLWithPath:[[[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask,YES) lastObject] stringByAppendingPathComponent:@"Stores"] stringByAppendingPathComponent:identifier]];
}

- (NSInteger)filesInProviderDirectory:(QSDefaultCoreDataStackProvider *)provider
{
    NSURL *directoryURL = [self directoryForProviderWithIdentifier:provider.identifier];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:directoryURL includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
    return enumerator.allObjects.count;
}

- (void)clearProviderDirectory:(QSDefaultCoreDataStackProvider *)provider
{
    QSCoreDataAdapter *changeManager = [[provider.adapterDictionary allValues] firstObject];
    [changeManager deleteChangeTracking];
    
    QSCoreDataStack *stack = [[provider.coreDataStacks allValues] firstObject];
    [stack deleteStore];
    
    NSURL *directoryURL = [NSURL fileURLWithPath:[[[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask,YES) lastObject] stringByAppendingPathComponent:@"Stores"] stringByAppendingPathComponent:provider.identifier]];
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:&error];
    if (error) {
        NSLog(@"Clear Provider Directory error: %@", error);
    }
}

- (void)testChangeManagerForRecordZoneID_createsNewChangeManagerAndStack
{
    XCTAssertTrue([self filesInProviderDirectory:self.provider] == 0);
    CKRecordZoneID *recordZoneID = [[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"];
    QSCoreDataAdapter *changeManager = (QSCoreDataAdapter *)[self.provider cloudKitSynchronizer:nil modelAdapterForRecordZoneID:recordZoneID];
    XCTAssertNotNil(changeManager);
    XCTAssertTrue([changeManager isKindOfClass:[QSCoreDataAdapter class]]);
    XCTAssertNotNil(changeManager.targetContext);
    XCTAssertNotNil(changeManager.stack.managedObjectContext);
    XCTAssertEqual(changeManager.recordZoneID, recordZoneID);
    XCTAssertEqual(self.provider.adapterDictionary.count, 1);
    XCTAssertEqual(self.provider.coreDataStacks.count, 1);
    XCTAssertTrue([self filesInProviderDirectory:self.provider] > 0);
}

- (void)testInit_existingStacks_createsChangeManagers
{
    NSURL *modelURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"QSExample" withExtension:@"momd"];
    NSURL *directoryURL = [self directoryForProviderWithIdentifier:@"provider2"];
    NSURL *targetStoreURL = [[directoryURL URLByAppendingPathComponent:@"zoneName.zoneID.zoneOwner"] URLByAppendingPathComponent:@"QSTargetStore"];
    NSURL *persistenceStoreURL = [[directoryURL URLByAppendingPathComponent:@"zoneName.zoneID.zoneOwner"] URLByAppendingPathComponent:@"QSPersistenceStore"];
    QSCoreDataStack *stack = [[QSCoreDataStack alloc] initWithStoreType:NSSQLiteStoreType model:[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL] storePath:targetStoreURL.path];
    QSCoreDataStack *persistenceStack = [[QSCoreDataStack alloc] initWithStoreType:NSSQLiteStoreType model:[QSCoreDataAdapter persistenceModel] storePath:persistenceStoreURL.path];
    
    stack = nil;
    persistenceStack = nil;
    
    QSDefaultCoreDataStackProvider *newProvider = [self providerWithID:@"provider2"];
    
    XCTAssertEqual(newProvider.adapterDictionary.count, 1);
    XCTAssertEqual(newProvider.coreDataStacks.count, 1);
}

- (void)testZoneWasDeletedWithZoneID_changeManagerHadBeenUsed_deletesChangeManagerAndRemovesFiles
{
    CKRecordZoneID *recordZoneID = [[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"];
    QSCoreDataAdapter *changeManager = (QSCoreDataAdapter *)[self.provider cloudKitSynchronizer:nil modelAdapterForRecordZoneID:recordZoneID];
    [changeManager saveToken:(CKServerChangeToken *)@"token"];
    XCTAssertNotNil(changeManager);
    XCTAssertEqual(self.provider.adapterDictionary.count, 1);
    
    [self.provider cloudKitSynchronizer:nil zoneWasDeletedWithZoneID:recordZoneID];
    
    XCTAssertEqual(self.provider.adapterDictionary.count, 0);
    XCTAssertEqual(self.provider.coreDataStacks.count, 0);
}

- (void)testZoneWasDeletedWithZoneID_changeManagerHadNotBeenUsedYet_preservesChangeManagerSoZoneCanBeRecreated
{
    CKRecordZoneID *recordZoneID = [[CKRecordZoneID alloc] initWithZoneName:@"zone" ownerName:@"owner"];
    QSCoreDataAdapter *changeManager = (QSCoreDataAdapter *)[self.provider cloudKitSynchronizer:nil modelAdapterForRecordZoneID:recordZoneID];
    XCTAssertNotNil(changeManager);
    XCTAssertEqual(self.provider.adapterDictionary.count, 1);
    
    [self.provider cloudKitSynchronizer:nil zoneWasDeletedWithZoneID:recordZoneID];
    
    XCTAssertEqual(self.provider.adapterDictionary.count, 1);
    XCTAssertEqual(self.provider.coreDataStacks.count, 1);
}

@end
