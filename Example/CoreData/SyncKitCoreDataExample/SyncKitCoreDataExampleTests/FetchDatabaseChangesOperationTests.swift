//
//  FetchDatabaseChangesOperationTests.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 09/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
@testable import SyncKit
import CloudKit
import XCTest

class FetchDatabaseChangesOperationTests: XCTestCase {
    
    var mockDatabase: MockCloudKitDatabase!
    
    override func setUp() {
        super.setUp()
        mockDatabase = MockCloudKitDatabase()
    }
    
    override func tearDown() {
        mockDatabase = nil
        super.tearDown()
    }
    
    func testOperation_returnsChangedZoneIDs() {
        let changedZoneIDs = [CKRecordZone.ID(zoneName: "name1", ownerName: "owner1"),
                              CKRecordZone.ID(zoneName: "name2", ownerName: "owner2")]
        mockDatabase.readyToFetchRecordZones = changedZoneIDs
        
        let expectation = self.expectation(description: "finished")
        var downloadedChanged: [CKRecordZone.ID]?
        let operation = FetchDatabaseChangesOperation(database: mockDatabase,
                                                      databaseToken: nil) { (_, downloaded, _) in
                                                        downloadedChanged = downloaded
                                                        expectation.fulfill()
        }
        
        operation.start()
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(changedZoneIDs.orderInsensitiveEqual(downloadedChanged))
    }
    
    func testOperation_returnsDeletedZoneIDs() {
        let deletedZoneIDs = [CKRecordZone.ID(zoneName: "name1", ownerName: "owner1"),
                              CKRecordZone.ID(zoneName: "name2", ownerName: "owner2")]
        mockDatabase.deletedRecordZoneIDs = deletedZoneIDs
        
        let expectation = self.expectation(description: "finished")
        var downloadedDeleted: [CKRecordZone.ID]?
        let operation = FetchDatabaseChangesOperation(database: mockDatabase,
                                                      databaseToken: nil) { (_, _, deleted) in
                                                        downloadedDeleted = deleted
                                                        expectation.fulfill()
        }
        
        operation.start()
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(deletedZoneIDs.orderInsensitiveEqual(downloadedDeleted))
    }
    
    func testOperation_internalOperationReturnsError_returnsError() {
        let changedZoneIDs = [CKRecordZone.ID(zoneName: "name1", ownerName: "owner1"),
                              CKRecordZone.ID(zoneName: "name2", ownerName: "owner2")]
        mockDatabase.readyToFetchRecordZones = changedZoneIDs
        mockDatabase.fetchError = TestError.error
        
        let expectation = self.expectation(description: "finished")
        var downloadedChanged: [CKRecordZone.ID]?
        let operation = FetchDatabaseChangesOperation(database: mockDatabase,
                                                      databaseToken: nil) { (_, downloaded, _) in
                                                        downloadedChanged = downloaded
        }
        
        var error: Error?
        operation.errorHandler = {
            error = $1
            expectation.fulfill()
        }
        
        operation.start()
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertNil(downloadedChanged)
        XCTAssertEqual(error as? TestError, TestError.error)
    }
}
