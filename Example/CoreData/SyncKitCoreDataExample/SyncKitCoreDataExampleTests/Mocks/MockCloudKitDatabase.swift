//
//  MockCloudKitDatabase.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 09/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import SyncKit
import CloudKit

class MockCloudKitDatabase: CloudKitDatabaseAdapter {
    var databaseScope: CKDatabase.Scope = .private
    
    
    // Values received during the test
    var receivedRecords = [CKRecord]()
    var deletedRecordIDs = [CKRecord.ID]()
    
    // Configuration
    var readyToFetchRecordZones: [CKRecordZone.ID]?
    var deletedRecordZoneIDs: [CKRecordZone.ID]?
    var readyToFetchRecords: [CKRecord]?
    var toDeleteRecordIDs: [CKRecord.ID]?
    var subscriptions: [CKSubscription]?
    
    var fetchRecordZoneError: Error?
    var fetchError: Error?
    var uploadError: Error?
    var filterUploadRecords: ((CKRecord) -> Bool) = { record in true }
    var serverChangedRecordBlock: ((CKRecord) -> (CKRecord?))?
    var uploadLimit: Int = .max
    
    var modifyRecordsOperationEnqueuedBlock: ((CKModifyRecordsOperation)->())?
    var fetchDatabaseChangesOperationEnqueuedBlock: ((CKFetchDatabaseChangesOperation) -> ())?
    var fetchRecordZoneChangesOperationEnqueuedBlock: ((CKFetchRecordZoneChangesOperation) -> ())?
    var deleteRecordZoneCalledBlock: ((CKRecordZone.ID)->())?
    var deleteSubscriptionCalledBlock: ((CKSubscription.ID)->())?
    var saveSubscriptionCalledBlock: ((CKSubscription)->())?
    var fetchAllSubscriptionsCalledBlock: (()->())?
    
    var subscriptionIdReturnValue: CKSubscription.ID?
    var serverToken: CKServerChangeToken? = CKServerChangeToken.stub()

    var changedRecordZoneIDs: [CKRecordZone.ID] {
        var zoneIDs = Set<CKRecordZone.ID>()
        zoneIDs.formUnion(readyToFetchRecordZones ?? [])
        readyToFetchRecords?.map { $0.recordID.zoneID }.forEach { zoneIDs.insert($0 )}
        toDeleteRecordIDs?.map { $0.zoneID }.forEach { zoneIDs.insert($0 )}
        return Array(zoneIDs)
    }
    
    func handleDatabaseChangesOperation(_ operation: CKFetchDatabaseChangesOperation) {
        fetchDatabaseChangesOperationEnqueuedBlock?(operation)
        
        changedRecordZoneIDs.forEach {
            operation.recordZoneWithIDChangedBlock?($0)
        }
        
        deletedRecordZoneIDs?.forEach {
            operation.recordZoneWithIDWasDeletedBlock?($0)
        }
        
        operation.fetchDatabaseChangesCompletionBlock?(serverToken, false, fetchError)
        
        deletedRecordZoneIDs = nil
        fetchError = nil
    }
    
    func handleFetchRecordZoneChangesOperation(_ operation: CKFetchRecordZoneChangesOperation) {
        fetchRecordZoneChangesOperationEnqueuedBlock?(operation)
        readyToFetchRecords?.forEach {
            operation.recordChangedBlock?($0)
        }
        toDeleteRecordIDs?.forEach {
            operation.recordWithIDWasDeletedBlock?($0, "recordType")
        }
        changedRecordZoneIDs.forEach {
            operation.recordZoneFetchCompletionBlock?($0,
                                                      serverToken,
                                                      Data(),
                                                      false,
                                                      nil)
        }
        
        operation.fetchRecordZoneChangesCompletionBlock?(fetchError)
        
        readyToFetchRecords = nil
        toDeleteRecordIDs = nil
        fetchError = nil
    }
    
    func handleModifyRecordsOperation(_ operation: CKModifyRecordsOperation) {
        
        modifyRecordsOperationEnqueuedBlock?(operation)
        
        guard (operation.recordsToSave?.count ?? 0) + (operation.recordIDsToDelete?.count ?? 0) < uploadLimit else {
            operation.modifyRecordsCompletionBlock?(nil, nil, CKError(.limitExceeded))
            return
        }
        
        receivedRecords.append(contentsOf: operation.recordsToSave ?? [])
        deletedRecordIDs.append(contentsOf: operation.recordIDsToDelete ?? [])
        
        var operationError: CKError?
        var savedRecords = operation.recordsToSave
        
        // Find records that should return serverRecordChanged error
        var perIDErrors: [CKRecord.ID: CKError] = [:]
        operation.recordsToSave?.forEach({ (record) in
            if let changedRecord = serverChangedRecordBlock?(record) {
                perIDErrors[record.recordID] = CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: changedRecord])
            }
        })
        savedRecords = savedRecords?.filter { perIDErrors[$0.recordID] == nil}
        if !perIDErrors.isEmpty {
            operationError = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: perIDErrors])
        }
        
        // Complete operation
        
        operation.recordsToSave?.forEach({ (record) in
            operation.perRecordCompletionBlock?(record, perIDErrors[record.recordID])
        })
        
        operation.modifyRecordsCompletionBlock?(savedRecords?.filter(filterUploadRecords), operation.recordIDsToDelete, operationError ?? uploadError)
    }
    
    func add(_ operation: CKDatabaseOperation) {
        if let operation = operation as? CKFetchRecordZoneChangesOperation {
            handleFetchRecordZoneChangesOperation(operation)
        } else if let operation = operation as? CKModifyRecordsOperation {
            handleModifyRecordsOperation(operation)
        } else if let operation = operation as? CKFetchDatabaseChangesOperation {
            handleDatabaseChangesOperation(operation)
        }
    }
    
    var savedRecordZone: CKRecordZone?
    func save(zone: CKRecordZone, completionHandler: @escaping (CKRecordZone?, Error?) -> Void) {
        savedRecordZone = zone
        completionHandler(zone, nil)
    }
    
    func fetchAllSubscriptions(completionHandler: @escaping ([CKSubscription]?, Error?) -> Void) {
        fetchAllSubscriptionsCalledBlock?()
        completionHandler(subscriptions, nil)
    }
    
    func save(subscription: CKSubscription, completionHandler: @escaping (CKSubscription?, Error?) -> Void) {
        saveSubscriptionCalledBlock?(subscription)
        if subscription is CKDatabaseSubscription {
            completionHandler(CKDatabaseSubscription(subscriptionID: subscriptionIdReturnValue!), nil)
        } else if let sub = subscription as? CKRecordZoneSubscription {
            completionHandler(CKRecordZoneSubscription(zoneID: sub.zoneID,
                                                       subscriptionID: subscriptionIdReturnValue!),
                              nil)
        }
    }
    
    func delete(withSubscriptionID subscriptionID: CKSubscription.ID, completionHandler: @escaping (String?, Error?) -> Void) {
        deleteSubscriptionCalledBlock?(subscriptionID)
        completionHandler(nil, nil)
    }
    
    func fetch(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone?, Error?) -> Void) {
        if let error = fetchRecordZoneError {
            completionHandler(nil, error)
        } else {
            let zone = CKRecordZone(zoneID: zoneID)
            completionHandler(zone, nil)
        }
    }
    
    func delete(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone.ID?, Error?) -> Void) {
        deleteRecordZoneCalledBlock?(zoneID)
        completionHandler(zoneID, nil)
    }
    
    var fetchCalledWithRecordID: CKRecord.ID?
    var fetchRecordResult: CKRecord?
    var fetchRecordError: Error?
    func fetch(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord?, Error?) -> Void) {
        fetchCalledWithRecordID = recordID
        completionHandler(fetchRecordResult, fetchRecordError)
    }
}
