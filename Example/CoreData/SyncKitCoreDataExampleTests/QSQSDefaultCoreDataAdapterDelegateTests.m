//
//  QSQSDefaultCoreDataAdapterDelegateTests.m
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 11/05/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <SyncKit/QSCoreDataAdapter.h>
#import <SyncKit/QSDefaultCoreDataAdapterDelegate.h>
#import "QSMockManagedObjectContext.h"
#import "QSMockCoreDataAdapter.h"

@interface QSQSDefaultCoreDataAdapterDelegateTests : XCTestCase

@property (nonatomic, strong) QSMockManagedObjectContext *mockContext;
@property (nonatomic, strong) QSMockCoreDataAdapter *mockCoreDataAdapter;
@property (nonatomic, strong) QSDefaultCoreDataAdapterDelegate *delegate;

@end

@implementation QSQSDefaultCoreDataAdapterDelegateTests

- (void)setUp {
    [super setUp];
    
    self.mockContext = [[QSMockManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.mockCoreDataAdapter = [[QSMockCoreDataAdapter alloc] init];
    self.mockCoreDataAdapter.contextValue = self.mockContext;
    self.delegate = [[QSDefaultCoreDataAdapterDelegate alloc] init];
}

- (void)tearDown {
    
    self.delegate = nil;
    self.mockContext = nil;
    
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testChangeManagerRequestsContextSave_savesContext
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"save finished"];
    [self.delegate coreDataAdapterRequestsContextSave:self.mockCoreDataAdapter completion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue(self.mockContext.saveCalled);
}

- (void)testChangeManagerRequestsContextSave_saveError_returnsError
{
    self.mockContext.saveError = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"save finished"];
    __block NSError *receivedError;
    [self.delegate coreDataAdapterRequestsContextSave:self.mockCoreDataAdapter completion:^(NSError *error) {
        receivedError = error;
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqual(receivedError, self.mockContext.saveError);
}

- (void)testChangeManagerDidImportChanges_savesImportContextThenTargetContext
{
    QSMockManagedObjectContext *importContext = [[QSMockManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"save finished"];
    [self.delegate coreDataAdapter:self.mockCoreDataAdapter didImportChanges:importContext completion:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertTrue(importContext.saveCalled);
    XCTAssertTrue(self.mockContext.saveCalled);
}

@end
