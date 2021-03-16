//
//  FetchZoneChangesOperationTests.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 09/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
@testable import SyncKit
import XCTest
import CloudKit

class FetchZoneChangesOperationTests: XCTestCase {
    
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
    
    func testOperation_returnsChangedRecords() {
        let zoneID = CKRecordZone.ID(zoneName: "zoneName", ownerName: "ownerName")
        let zoneID2 = CKRecordZone.ID(zoneName: "zoneName2", ownerName: "ownerName2")
        let changedRecords = [record(name: "record1", zoneID: zoneID),
                              record(name: "record2", zoneID: zoneID),
                              record(name: "record1", zoneID: zoneID2),
                              record(name: "record1", zoneID: zoneID2)]
        
        mockDatabase.readyToFetchRecords = changedRecords
        
        var downloadedRecords = [CKRecord]()
        
        let expectation = self.expectation(description: "finished")
        let operation = FetchZoneChangesOperation(database: mockDatabase,
                                                  zoneIDs: [zoneID, zoneID2],
                                                  zoneChangeTokens: [:],
                                                  modelVersion: 0,
                                                  ignoreDeviceIdentifier: "",
                                                  desiredKeys: nil) { (zoneResults) in
                                                    
                                                    let zoneResult = zoneResults[zoneID]
                                                    zoneResult?.downloadedRecords.forEach {
                                                        downloadedRecords.append($0)
                                                    }
                                                    
                                                    let zoneResult2 = zoneResults[zoneID2]
                                                    zoneResult2?.downloadedRecords.forEach {
                                                        downloadedRecords.append($0)
                                                    }
                                                    
                                                    expectation.fulfill()
        }
        
        operation.start()
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(changedRecords.orderInsensitiveEqual(downloadedRecords))
    }
    
    func testOperation_returnsDeletedRecordIDs() {
        let zoneID = CKRecordZone.ID(zoneName: "zoneName", ownerName: "ownerName")
        let zoneID2 = CKRecordZone.ID(zoneName: "zoneName2", ownerName: "ownerName2")
        let deletedRecordIDs = [CKRecord.ID(recordName: "record1", zoneID: zoneID),
                                CKRecord.ID(recordName: "record2", zoneID: zoneID),
                                CKRecord.ID(recordName: "record1", zoneID: zoneID2),
                                CKRecord.ID(recordName: "record2", zoneID: zoneID2)]
        
        mockDatabase.toDeleteRecordIDs = deletedRecordIDs
        
        var downloadedRecords = [CKRecord.ID]()
        
        let expectation = self.expectation(description: "finished")
        let operation = FetchZoneChangesOperation(database: mockDatabase,
                                                  zoneIDs: [zoneID, zoneID2],
                                                  zoneChangeTokens: [:],
                                                  modelVersion: 0,
                                                  ignoreDeviceIdentifier: "",
                                                  desiredKeys: nil) { (zoneResults) in
                                                    
                                                    let zoneResult = zoneResults[zoneID]
                                                    zoneResult?.deletedRecordIDs.forEach {
                                                        downloadedRecords.append($0)
                                                    }
                                                    
                                                    let zoneResult2 = zoneResults[zoneID2]
                                                    zoneResult2?.deletedRecordIDs.forEach {
                                                        downloadedRecords.append($0)
                                                    }
                                                    
                                                    expectation.fulfill()
        }
        
        operation.start()
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(deletedRecordIDs.orderInsensitiveEqual(downloadedRecords))
    }
    
    func testOperation_internalOperationReturnsError_returnsError() {
        let zoneID = CKRecordZone.ID(zoneName: "zoneName", ownerName: "ownerName")
        let zoneID2 = CKRecordZone.ID(zoneName: "zoneName2", ownerName: "ownerName2")
        let changedRecords = [record(name: "record1", zoneID: zoneID),
                              record(name: "record2", zoneID: zoneID),
                              record(name: "record1", zoneID: zoneID2),
                              record(name: "record1", zoneID: zoneID2)]
        
        mockDatabase.readyToFetchRecords = changedRecords
        mockDatabase.fetchError = TestError.error
        
        var downloadedRecords = [CKRecord]()
        var error: Error?
        
        let expectation = self.expectation(description: "finished")
        let operation = FetchZoneChangesOperation(database: mockDatabase,
                                                  zoneIDs: [zoneID, zoneID2],
                                                  zoneChangeTokens: [:],
                                                  modelVersion: 0,
                                                  ignoreDeviceIdentifier: "",
                                                  desiredKeys: nil) { (zoneResults) in
                                                    
                                                    let zoneResult = zoneResults[zoneID]
                                                    zoneResult?.downloadedRecords.forEach {
                                                        downloadedRecords.append($0)
                                                    }
                                                    
                                                    let zoneResult2 = zoneResults[zoneID2]
                                                    zoneResult2?.downloadedRecords.forEach {
                                                        downloadedRecords.append($0)
                                                    }
        }
        
        operation.errorHandler = {
            error = $1
            expectation.fulfill()
        }
        
        operation.start()
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(downloadedRecords.count, 0)
        XCTAssertEqual(error as? TestError, TestError.error)
    }
}
