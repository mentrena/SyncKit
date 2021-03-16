//
//  QSFetchZoneChangesOperation.swift
//  Pods
//
//  Created by Manuel Entrena on 18/05/2018.
//

import Foundation
import CloudKit

class FetchZoneChangesOperationZoneResult: NSObject {
    
    var downloadedRecords = [CKRecord]()
    var deletedRecordIDs = [CKRecord.ID]()
    var serverChangeToken: CKServerChangeToken?
    var error: Error?
    var moreComing: Bool = false
}

class FetchZoneChangesOperation: CloudKitSynchronizerOperation {
    
    let database: CloudKitDatabaseAdapter
    let zoneIDs: [CKRecordZone.ID]
    var zoneChangeTokens: [CKRecordZone.ID: CKServerChangeToken]
    let modelVersion: Int
    let ignoreDeviceIdentifier: String?
    let completion: ([CKRecordZone.ID: FetchZoneChangesOperationZoneResult]) -> ()
    let desiredKeys: [String]?
    
    var zoneResults = [CKRecordZone.ID: FetchZoneChangesOperationZoneResult]()
    
    let dispatchQueue = DispatchQueue(label: "fetchZoneChangesDispatchQueue")
    weak var internalOperation: CKFetchRecordZoneChangesOperation?
    
    init(database: CloudKitDatabaseAdapter,
                      zoneIDs: [CKRecordZone.ID],
                      zoneChangeTokens: [CKRecordZone.ID: CKServerChangeToken],
                      modelVersion: Int,
                      ignoreDeviceIdentifier: String?,
                      desiredKeys: [String]?,
                      completion: @escaping ([CKRecordZone.ID: FetchZoneChangesOperationZoneResult]) -> ()) {
        
        self.database = database
        self.zoneIDs = zoneIDs
        self.zoneChangeTokens = zoneChangeTokens
        self.modelVersion = modelVersion
        self.ignoreDeviceIdentifier = ignoreDeviceIdentifier
        self.desiredKeys = desiredKeys
        self.completion = completion
        
        super.init()
    }
    
    override func start() {
        
        for zone in zoneIDs {
            zoneResults[zone] = FetchZoneChangesOperationZoneResult()
        }
        performFetchOperation(with: zoneIDs)
    }
    
    func performFetchOperation(with zones: [CKRecordZone.ID]) {
        
        var higherModelVersionFound = false
        var zoneOptions = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions]()
        
        for zoneID in zones {
            let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
            options.previousServerChangeToken = zoneChangeTokens[zoneID]
            options.desiredKeys = desiredKeys
            zoneOptions[zoneID] = options
        }
        
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zones, optionsByRecordZoneID: zoneOptions)
        operation.fetchAllChanges = false
        
        operation.recordChangedBlock = { record in
            
            let ignoreDeviceIdentifier: String = self.ignoreDeviceIdentifier ?? " "
            self.dispatchQueue.async {
                
                let isShare = record is CKShare
                if ignoreDeviceIdentifier != record[CloudKitSynchronizer.deviceUUIDKey] as? String || isShare {
                    
                    if !isShare,
                        let version = record[CloudKitSynchronizer.modelCompatibilityVersionKey] as? Int,
                        self.modelVersion > 0 && version > self.modelVersion {
                        
                        higherModelVersionFound = true
                    } else {
                        
                        self.zoneResults[record.recordID.zoneID]?.downloadedRecords.append(record)
                    }
                }
            }
        }
        
        operation.recordWithIDWasDeletedBlock = { recordID, recordType in
            self.dispatchQueue.async {
                self.zoneResults[recordID.zoneID]?.deletedRecordIDs.append(recordID)
            }
        }
        
        operation.recordZoneFetchCompletionBlock = {
            zoneID, serverChangeToken, clientChangeTokenData, moreComing, recordZoneError in
            
            self.dispatchQueue.async {
                
                let results = self.zoneResults[zoneID]!
                
                results.error = recordZoneError
                results.serverChangeToken = serverChangeToken
                
                if !higherModelVersionFound {
                    if moreComing {
                        results.moreComing = true
                    }
                }
            }
        }
        
        operation.fetchRecordZoneChangesCompletionBlock = { operationError in
            
            self.dispatchQueue.async {
                if let error = operationError,
                    (error as NSError).code != CKError.partialFailure.rawValue { // Partial errors are returned per zone
                    self.finish(error: error)
                } else if higherModelVersionFound {
                    self.finish(error: CloudKitSynchronizer.SyncError.higherModelVersionFound)
                } else if self.isCancelled {
                    self.finish(error: CloudKitSynchronizer.SyncError.cancelled)
                } else {
                    self.completion(self.zoneResults)
                    self.finish(error: nil)
                }
            }
        }
        
        internalOperation = operation
        self.database.add(operation)
    }
    
    override func cancel() {
        internalOperation?.cancel()
        super.cancel()
    }
}
