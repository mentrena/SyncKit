//
//  ModifyRecordsOperationTests.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 10/09/2020.
//  Copyright © 2020 Manuel Entrena. All rights reserved.
//

import Foundation
@testable import SyncKit
import XCTest
import CloudKit

class ModifyRecordsOperationTests: XCTestCase {
    
    var mockDatabase: MockCloudKitDatabase!
    
    override func setUp() {
        super.setUp()
        mockDatabase = MockCloudKitDatabase()
    }
    
    override func tearDown() {
        mockDatabase = nil
        super.tearDown()
    }
    
    func record(name: String, zoneID: CKRecordZone.ID) -> CKRecord {
        return CKRecord(recordType: "testType", recordID: CKRecord.ID(recordName: name, zoneID: zoneID))
    }
    
    func testOperation_uploadsRecords() {
        
        let zoneID = CKRecordZone.ID(zoneName: "zoneName", ownerName: "ownerName")

        let changedRecords = [record(name: "record1", zoneID: zoneID),
                              record(name: "record2", zoneID: zoneID),
                              record(name: "record3", zoneID: zoneID),
                              record(name: "record4", zoneID: zoneID)]
        
        let deletedIDs = [CKRecord.ID(recordName: "record5", zoneID: zoneID),
                          CKRecord.ID(recordName: "record6", zoneID: zoneID)]
        
        let expectation = self.expectation(description: "finished")
        
        let operation = ModifyRecordsOperation(database: mockDatabase,
                                               records: changedRecords,
                                               recordIDsToDelete: deletedIDs) { (saved, deleted, _, error) in
                                                expectation.fulfill()
        }
        
        operation.start()
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(mockDatabase.receivedRecords, changedRecords)
        XCTAssertEqual(mockDatabase.deletedRecordIDs, deletedIDs)
    }
    
    func testOperation_detectsConflictedRecords() {
        let zoneID = CKRecordZone.ID(zoneName: "zoneName", ownerName: "ownerName")

        let changedRecords = [record(name: "record1", zoneID: zoneID),
                              record(name: "record2", zoneID: zoneID),
                              record(name: "record3", zoneID: zoneID),
                              record(name: "record4", zoneID: zoneID)]
        
        mockDatabase.serverChangedRecordBlock = { record in
            if changedRecords.suffix(2).contains(record) {
                return record
            } else {
                return nil
            }
        }
        
        let expectation = self.expectation(description: "finished")
        
        var savedRecords: [CKRecord]?
        var conflictedRecords: [CKRecord]?
        
        let operation = ModifyRecordsOperation(database: mockDatabase,
                                               records: changedRecords,
                                               recordIDsToDelete: nil) { (saved, deleted, conflicted, error) in
                                                savedRecords = saved
                                                conflictedRecords = conflicted
                                                expectation.fulfill()
        }
        
        operation.start()
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(savedRecords, Array(changedRecords.prefix(2)))
        XCTAssertEqual(conflictedRecords, changedRecords.suffix(2))
    }
    


    func testOperation_internalOperationReturnsError_allowsError() {
        let zoneID = CKRecordZone.ID(zoneName: "zoneName", ownerName: "ownerName")

        let changedRecords = [record(name: "record1", zoneID: zoneID),
                              record(name: "record2", zoneID: zoneID),
                              record(name: "record3", zoneID: zoneID),
                              record(name: "record4", zoneID: zoneID)]
        
        mockDatabase.uploadError = TestError.error
        
        let expectation = self.expectation(description: "finished")
        
        var error: Error?
        
        let operation = ModifyRecordsOperation(database: mockDatabase,
                                               records: changedRecords,
                                               recordIDsToDelete: nil) { (_, _, _, error) in
                                                expectation.fulfill()
        }

        operation.errorHandler = {
            error = $1
            expectation.fulfill()
        }

        operation.start()

        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertNil(error as? TestError)
    }
}
