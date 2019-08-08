//
//  CloudKitSynchronizerTests.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 11/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import XCTest
import SyncKit
import CloudKit

class CloudKitSynchronizerTests: XCTestCase {
    
    var synchronizer: CloudKitSynchronizer!
    var mockDatabase: MockCloudKitDatabase!
    var mockAdapter: MockModelAdapter!
    var recordZoneID: CKRecordZone.ID!
    var mockKeyValueStore: MockKeyValueStore!
    var mockAdapterProvider: MockAdapterProvider!
    
    override func setUp() {
        super.setUp()
        
        mockKeyValueStore = MockKeyValueStore()
        mockDatabase = MockCloudKitDatabase()
        recordZoneID = CKRecordZone.ID(zoneName: "zone", ownerName: "owner")
        mockAdapter = MockModelAdapter()
        mockAdapter.recordZoneIDValue = recordZoneID
        mockAdapterProvider = MockAdapterProvider()
        mockAdapterProvider.modelAdapterValue = mockAdapter
        
        synchronizer = CloudKitSynchronizer(identifier: "testID",
                                            containerIdentifier: "any",
                                            database: mockDatabase,
                                            adapterProvider: mockAdapterProvider,
                                            keyValueStore: mockKeyValueStore)
        synchronizer.addModelAdapter(mockAdapter)
    }
    
    override func tearDown() {
        super.tearDown()
        
        synchronizer = nil
        mockAdapterProvider = nil
        mockAdapter = nil
        mockDatabase = nil
        recordZoneID = nil
        mockKeyValueStore = nil
    }
    
    func clearAllUserDefaults() {
        mockKeyValueStore.clear()
    }
    
    func objectArray(range: ClosedRange<Int>) -> [QSObject] {
        return range.map { QSObject(identifier: String($0), number: $0) }
    }
    
    func createSubscription() -> CKRecordZoneSubscription {
        let subscription = CKRecordZoneSubscription(zoneID: recordZoneID)
        var notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        return subscription
    }
    
    func testSynchronize_twoObjectsToUpload_uploadsThem() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...2)
        mockAdapter.objects = objects
        mockAdapter.markForUpload(objects)
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(mockDatabase.receivedRecords.count, 2)
    }
    
    func testSynchronize_oneObjectToDelete_deletesObject() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...2)
        mockAdapter.objects = objects
        mockAdapter.markForDeletion(objects.suffix(1))
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(mockDatabase.deletedRecordIDs.first, objects[1].recordID(zoneID: recordZoneID))
        XCTAssertEqual(mockAdapter.objects, Array(objects.prefix(1)))
    }
    
    func testSynchronize_oneObjectToFetch_downloadsObject() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...2)
        mockAdapter.objects = objects
        
        let object = QSObject(identifier: "3", number: 3)
        mockDatabase.readyToFetchRecords = [object.record(with: recordZoneID)]
        
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        var result = objects
        result.append(object)
        XCTAssertEqual(mockAdapter.objects, result)
    }
    
    func testSynchronize_objectsToUploadAndDeleteAndFetch_UpdatesAll() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...4)
        mockAdapter.objects = objects
        mockAdapter.markForUpload([objects.first!])
        mockAdapter.markForDeletion([objects.last!])
        
        let newObject = QSObject(identifier: "5", number: 5)
        mockDatabase.readyToFetchRecords = [newObject.record(with: recordZoneID)]
        
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(mockDatabase.deletedRecordIDs, [objects.last!.recordID(zoneID: recordZoneID)])
        XCTAssertEqual(mockDatabase.receivedRecords.count, 1)
        let receivedRecord = mockDatabase.receivedRecords.first
        XCTAssertEqual(receivedRecord?.recordID, objects.first!.recordID(zoneID: recordZoneID))
        XCTAssertEqual(mockAdapter.objects.count, 4)
        XCTAssertNotNil(mockAdapter.objects.contains(newObject))
    }
    
    func testSynchronize_errorInFetch_endsWithError() {
        let expectation = self.expectation(description: "sync finished")
        let error = TestError.error
        mockDatabase.fetchError = error
        
        var receivedError: Error?
        synchronizer.synchronize { (error) in
            receivedError = error
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(receivedError as? TestError, TestError.error)
    }
    
    func testSynchronize_errorInUpload_endsWithError() {
        let expectation = self.expectation(description: "sync finished")
        let error = TestError.error
        mockDatabase.uploadError = error
        
        mockAdapter.objects = [QSObject(identifier: "1", number: 1)]
        mockAdapter.markForUpload(mockAdapter.objects)
        
        var receivedError: Error?
        synchronizer.synchronize { (error) in
            receivedError = error
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(receivedError as? TestError, TestError.error)
    }
    
    func testSynchronize_recordZoneNotCreated_createsRecordZone() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...2)
        mockAdapter.objects = objects
        mockAdapter.markForUpload(objects)
        
        mockDatabase.fetchRecordZoneError = NSError(domain: CKErrorDomain, code: CKError.zoneNotFound.rawValue, userInfo: nil)
        
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertNotNil(mockDatabase.savedRecordZone)
    }
    
    func testSynchronize_recordZoneHadBeenCreated_failsInUpload() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...2)
        mockAdapter.objects = objects
        mockAdapter.markForUpload(objects)
        mockAdapter.saveToken(CKServerChangeToken.stub())
        
        mockDatabase.uploadError = NSError(domain: CKErrorDomain, code: CKError.zoneNotFound.rawValue, userInfo: nil)
        var receivedError: Error?
        synchronizer.synchronize { (error) in
            receivedError = error
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertNil(mockDatabase.savedRecordZone)
        XCTAssertEqual((receivedError as NSError?)?.code, CKError.zoneNotFound.rawValue)
    }
    
    func testSynchronize_limitExceededError_decreasesBatchSizeAndEndsWithError() {
        let expectation = self.expectation(description: "sync finished")
        let batchSize = synchronizer.batchSize
        let error = NSError(domain: CKErrorDomain, code: CKError.limitExceeded.rawValue, userInfo: nil)
        mockDatabase.uploadError = error
        let object = QSObject(identifier: "1", number: 1)
        mockAdapter.objects = [object]
        mockAdapter.markForUpload([object])
        
        var receivedError: Error?
        synchronizer.synchronize { (error) in
            receivedError = error
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        let halfBatchSize = synchronizer.batchSize
        XCTAssertEqual(receivedError as NSError?, error)
        XCTAssertEqual(halfBatchSize, batchSize / 2)
        
        /*
         Synchronize without error increases batch size
         */
        mockDatabase.uploadError = nil
        mockAdapter.objects = [object]
        mockAdapter.markForUpload([object])
        let expectation2 = self.expectation(description: "sync finished")
        synchronizer.synchronize { (error) in
            receivedError = error
            expectation2.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertNil(receivedError)
        XCTAssertTrue(synchronizer.batchSize > halfBatchSize)
    }
    
    func testSynchronize_limitExceededErrorInPartialError_decreasesBatchSizeAndEndsWithError() {
        let expectation = self.expectation(description: "sync finished")
        let batchSize = synchronizer.batchSize
        let innerError = NSError(domain: CKErrorDomain,
                                 code: CKError.limitExceeded.rawValue,
                                 userInfo: nil)
        let error = NSError(domain: CKErrorDomain,
                            code: CKError.partialFailure.rawValue,
                            userInfo: [CKPartialErrorsByItemIDKey: [CKRecord.ID(recordName: "itemID", zoneID: recordZoneID): innerError]])
        mockDatabase.uploadError = error
        let object = QSObject(identifier: "1", number: 1)
        mockAdapter.objects = [object]
        mockAdapter.markForUpload([object])
        var receivedError: Error?
        
        synchronizer.synchronize { (error) in
            receivedError = error
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(receivedError as NSError?, error)
        XCTAssertEqual(synchronizer.batchSize, batchSize / 2)
    }
    
    func testSynchronize_moreThanBatchSizeItems_performsMultipleUploads() {
        let expectation = self.expectation(description: "sync finished")
        
        let objects = objectArray(range: 0...(synchronizer.batchSize + 10))
        mockAdapter.objects = objects
        mockAdapter.markForUpload(objects)
        
        var operationCount = 0
        mockDatabase.modifyRecordsOperationEnqueuedBlock = { _ in
            operationCount = operationCount + 1
        }
        
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(operationCount, 2)
    }
    
    func testSynchronize_storesServerTokenAfterFetch() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...2)
        mockAdapter.objects = objects
        mockAdapter.markForUpload(objects)
        mockAdapter.saveToken(nil)
        
        XCTAssertNil(mockAdapter.serverChangeToken)
        
        mockDatabase.modifyRecordsOperationEnqueuedBlock = { op in
            self.mockDatabase.readyToFetchRecords = op.recordsToSave
        }
        
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertNotNil(mockAdapter.serverChangeToken)
    }
    
    func testEraseLocal_deletesAdapterTracking() {
        synchronizer.eraseLocalMetadata()
        XCTAssertTrue(mockAdapter.deleteChangeTrackingCalled)
    }
    
    func testdeleteRecordZoneForAdapter_deletesRecordZone() {
        var called = false
        mockDatabase.deleteRecordZoneCalledBlock = { _ in
            called = true
        }
        synchronizer.deleteRecordZone(for: mockAdapter, completion: nil)
        
        XCTAssertTrue(called)
    }
    
    func testSubscribeForRecordZoneNotifications_savesToDatabase() {
        clearAllUserDefaults()
        
        let expectation = self.expectation(description: "save subscription called")
        
        var called = false
        mockDatabase.subscriptionIdReturnValue = "123"
        mockDatabase.saveSubscriptionCalledBlock = { _ in
            called = true
        }
        
        synchronizer.subscribeForChanges(in: recordZoneID) { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        let subscriptionID = synchronizer.subscriptionID(forRecordZoneID: recordZoneID)
        XCTAssertTrue(called)
        XCTAssertEqual(subscriptionID, "123")
    }
    
    func testSubscribeForDatabaseNotifications_savesToDatabase() {
        let expectation = self.expectation(description: "save subscription called")
        var called = false
        
        mockDatabase.databaseScope = .shared
        mockDatabase.subscriptionIdReturnValue = "456"
        mockDatabase.saveSubscriptionCalledBlock = { _ in
            called = true
        }
        
        synchronizer.subscribeForChangesInDatabase { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        let subscriptionID = synchronizer.subscriptionIDForDatabaseSubscription()
        
        XCTAssertTrue(called)
        XCTAssertEqual(subscriptionID, "456")
    }
    
    func testSubscribeForUpdateNotifications_existingSubscription_updatesSubscriptionID() {
        let subscription = createSubscription()
        mockDatabase.subscriptions = [subscription]
        let expectation = self.expectation(description: "Fetched subscription")
        mockDatabase.fetchAllSubscriptionsCalledBlock = {
            expectation.fulfill()
        }
        
        var saveCalled = false
        mockDatabase.saveSubscriptionCalledBlock = { _ in
            saveCalled = true
        }
        
        synchronizer.subscribeForChanges(in: recordZoneID, completion: nil)
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertFalse(saveCalled)
        XCTAssertEqual(synchronizer.subscriptionID(forRecordZoneID: recordZoneID), subscription.subscriptionID)
    }
    
    func testDeleteSubscription_deletesOnDatabase() {
        mockDatabase.subscriptionIdReturnValue = "subscription"
        let expectation = self.expectation(description: "saved")
        synchronizer.subscribeForChanges(in: recordZoneID) { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(synchronizer.subscriptionID(forRecordZoneID: recordZoneID))
        
        let deleted = self.expectation(description: "delete subscription called")
        var called = false
        mockDatabase.deleteSubscriptionCalledBlock = { _ in
            called = true
        }
        
        synchronizer.cancelSubscriptionForChanges(in: recordZoneID) { (_) in
            deleted.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        let subscriptionID = synchronizer.subscriptionID(forRecordZoneID: recordZoneID)
        
        XCTAssertTrue(called)
        XCTAssertNil(subscriptionID)
    }
    
    func testDeleteSubscription_noLocalSubscriptionButRemoteOne_deletesOnDatabase() {
        let subscription = createSubscription()
        mockDatabase.subscriptions = [subscription]
        
        let deleted = self.expectation(description: "delete called")
        var deletedSubscriptionID: CKSubscription.ID?
        mockDatabase.deleteSubscriptionCalledBlock = { subscriptionID in
            deletedSubscriptionID = subscriptionID
            deleted.fulfill()
        }
        
        synchronizer.cancelSubscriptionForChanges(in: recordZoneID, completion: nil)
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(deletedSubscriptionID, subscription.subscriptionID)
    }
    
    func testSynchronize_objectChanges_callsAllAdapterMethods() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...3)
        mockAdapter.objects = objects
        mockAdapter.markForUpload([objects[1]])
        mockAdapter.markForDeletion([objects[2]])
        
        let newObject = QSObject(identifier: "4", number: 4)
        
        mockDatabase.readyToFetchRecords = [newObject.record(with: recordZoneID)]
        mockDatabase.toDeleteRecordIDs = [objects.first!.recordID(zoneID: recordZoneID)]
        
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(mockAdapter.prepareToImportCalled)
        XCTAssertTrue(mockAdapter.saveChangesCalled)
        XCTAssertTrue(mockAdapter.deleteRecordsCalled)
        XCTAssertTrue(mockAdapter.recordsToUploadCalled)
        XCTAssertTrue(mockAdapter.recordIDsMarkedForDeletionCalled)
        XCTAssertTrue(mockAdapter.didUploadCalled)
        XCTAssertTrue(mockAdapter.didDeleteCalled)
        XCTAssertTrue(mockAdapter.persistImportedChangesCalled)
        XCTAssertTrue(mockAdapter.didFinishImportCalled)
    }
    
    func testSynchronize_newerModelVersion_cancelsSynchronizationWithError() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...3)
        mockAdapter.objects = objects
        mockAdapter.markForUpload(objects)
        
        synchronizer.compatibilityVersion = 2
        
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        let synchronizer2 = CloudKitSynchronizer(identifier: "testID2",
                                                 containerIdentifier: "any",
                                                 database: mockDatabase,
                                                 adapterProvider: mockAdapterProvider,
                                                 keyValueStore: mockKeyValueStore)
        mockDatabase.readyToFetchRecords = mockDatabase.receivedRecords
        
        let expectation2 = self.expectation(description: "sync finished")
        
        synchronizer2.compatibilityVersion = 1
        var syncError: Error?
        
        synchronizer2.synchronize { (error) in
            syncError = error
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(syncError as? CloudKitSynchronizer.SyncError, CloudKitSynchronizer.SyncError.higherModelVersionFound)
    }
    
    func testSynchronize_usesModelVersion_synchronizesWithPreviousVersions() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...3)
        mockAdapter.objects = objects
        mockAdapter.markForUpload(objects)
        
        synchronizer.compatibilityVersion = 1
        
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        let synchronizer2 = CloudKitSynchronizer(identifier: "testID2",
                                                 containerIdentifier: "any",
                                                 database: mockDatabase,
                                                 adapterProvider: mockAdapterProvider,
                                                 keyValueStore: mockKeyValueStore)
        mockDatabase.readyToFetchRecords = mockDatabase.receivedRecords
        
        let expectation2 = self.expectation(description: "sync finished")
        
        synchronizer2.compatibilityVersion = 2
        var syncError: Error?
        
        synchronizer2.synchronize { (error) in
            syncError = error
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNil(syncError)
    }
    
    func testSynchronize_downloadOnly_doesNotUploadChanges() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...3)
        mockAdapter.objects = objects
        mockAdapter.markForUpload(objects)
        
        let object1 = QSObject(identifier: "4", number: 4)
        let object2 = QSObject(identifier: "3", number: 5)
        mockDatabase.readyToFetchRecords = [object1.record(with: recordZoneID),
                                            object2.record(with: recordZoneID)]
        synchronizer.syncMode = .downloadOnly
        
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        let updatedObject = mockAdapter.objects.first { $0.identifier == "3" }
        XCTAssertEqual(mockDatabase.receivedRecords.count, 0)
        XCTAssertEqual(mockAdapter.objects.count, 4)
        XCTAssertEqual(updatedObject?.number, 5)
    }
    
    func testSynchronize_newRecordZone_callsAdapterProvider() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...2)
        mockAdapter.objects = objects
        
        let object = QSObject(identifier: "3", number: 3)
        mockDatabase.readyToFetchRecords = [object.record(with: recordZoneID)]
        
        synchronizer.removeModelAdapter(mockAdapter)
        
        XCTAssertTrue(synchronizer.modelAdapters.count == 0)
        
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(mockAdapterProvider.modelAdapterForRecordZoneIDCalled)
        XCTAssertTrue(synchronizer.modelAdapters.count == 1)
    }
    
    func testSynchronize_recordZoneWasDeleted_callsAdapterProvider() {
        let expectation = self.expectation(description: "sync finished")
        let objects = objectArray(range: 1...2)
        mockAdapter.objects = objects
        
        mockDatabase.deletedRecordZoneIDs = [recordZoneID]
        
        synchronizer.synchronize { (_) in
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(mockAdapterProvider.zoneWasDeletedWithIDCalled)
    }
}
