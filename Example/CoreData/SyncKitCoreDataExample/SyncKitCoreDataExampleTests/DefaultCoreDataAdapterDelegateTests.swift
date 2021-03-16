//
//  DefaultCoreDataAdapterDelegateTests.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 10/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
@testable import SyncKit
import XCTest
import CoreData
import CloudKit

class DefaultCoreDataAdapterDelegateTests: XCTestCase {
    
    var mockContext: MockManagedObjectContext!
    var adapter: CoreDataAdapter!
    var adapterDelegate: DefaultCoreDataAdapterDelegate!
    
    override func setUp() {
        super.setUp()
        mockContext = MockManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        adapterDelegate = DefaultCoreDataAdapterDelegate()
        adapter = CoreDataAdapter(persistenceStack: CoreDataStack(storeType: NSInMemoryStoreType,
                                                                  model: CoreDataAdapter.persistenceModel,
                                                                  storeURL: nil),
                                  targetContext: mockContext,
                                  recordZoneID: CKRecordZone.ID(zoneName: "zone", ownerName: "owner"),
                                  delegate: adapterDelegate)
    }
    
    override func tearDown() {
        adapter = nil
        adapterDelegate = nil
        mockContext = nil
        super.tearDown()
    }
    
    func testChangeManagerRequestsContextSave_savesContext() {
        let expectation = self.expectation(description: "save finished")
        adapterDelegate.coreDataAdapter(adapter) { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(mockContext.saveCalled)
    }
    
    func testChangeManagerRequestsContextSave_saveError_returnsError() {
        mockContext.saveError = TestError.error
        let expectation = self.expectation(description: "save finished")
        var receivedError: Error?
        adapterDelegate.coreDataAdapter(adapter) { (error) in
            receivedError = error
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(receivedError as? TestError, TestError.error)
    }
    
    func testChangeManagerDidImportChanges_savesImportContextThenTargetContext() {
        let importContext = MockManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        let expectation = self.expectation(description: "save finished")
        adapterDelegate.coreDataAdapter(adapter, didImportChanges: importContext) { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(importContext.saveCalled)
        XCTAssertTrue(mockContext.saveCalled)
    }
}
