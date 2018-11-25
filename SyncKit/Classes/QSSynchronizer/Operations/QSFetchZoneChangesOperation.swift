//
//  QSFetchZoneChangesOperation.swift
//  Pods
//
//  Created by Manuel Entrena on 18/05/2018.
//

import Foundation
import CloudKit

public class QSFetchZoneChangesOperationZoneResult: NSObject {
    
    @objc public var downloadedRecords = [CKRecord]()
    @objc public var deletedRecordIDs = [CKRecord.ID]()
    @objc public var serverChangeToken: CKServerChangeToken?
    @objc public var error: Error?
    @objc public var moreComing: Bool = false
}

public class QSFetchZoneChangesOperation: QSCloudKitSynchronizerOperation {
    
    let database: CKDatabase
    let zoneIDs: [CKRecordZone.ID]
    var zoneChangeTokens: [CKRecordZone.ID: CKServerChangeToken]
    let modelVersion: Int
    let ignoreDeviceIdentifier: String?
    let completion: ([CKRecordZone.ID: QSFetchZoneChangesOperationZoneResult]) -> ()
    let desiredKeys: [String]?
    
    var zoneResults = [CKRecordZone.ID: QSFetchZoneChangesOperationZoneResult]()
    
    let dispatchQueue = DispatchQueue(label: "fetchZoneChangesDispatchQueue")
    weak var internalOperation: CKFetchRecordZoneChangesOperation?
    
    @objc public init(database: CKDatabase,
                      zoneIDs: [CKRecordZone.ID],
                      zoneChangeTokens: [CKRecordZone.ID: CKServerChangeToken],
                      modelVersion: Int,
                      ignoreDeviceIdentifier: String?,
                      desiredKeys: [String]?,
                      completion: @escaping ([CKRecordZone.ID: QSFetchZoneChangesOperationZoneResult]) -> ()) {
        
        self.database = database
        self.zoneIDs = zoneIDs
        self.zoneChangeTokens = zoneChangeTokens
        self.modelVersion = modelVersion
        self.ignoreDeviceIdentifier = ignoreDeviceIdentifier
        self.desiredKeys = desiredKeys
        self.completion = completion
        
        super.init()
    }
    
    override public func start() {
        
        for zone in zoneIDs {
            zoneResults[zone] = QSFetchZoneChangesOperationZoneResult()
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
                if ignoreDeviceIdentifier != record[QSCloudKitDeviceUUIDKey] as? String || isShare {
                    
                    if !isShare,
                        let version = record[QSCloudKitModelCompatibilityVersionKey] as? Int,
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
                    self.finish(error: NSError(domain: QSCloudKitSynchronizerErrorDomain, code: QSCloudKitSynchronizerErrorCode.higherModelVersionFound.rawValue, userInfo: nil))
                } else if self.isCancelled {
                    self.finish(error: NSError(domain: QSCloudKitSynchronizerErrorDomain, code: QSCloudKitSynchronizerErrorCode.cancelled.rawValue, userInfo: nil))
                } else {
                    self.completion(self.zoneResults)
                    self.finish(error: nil)
                }
            }
        }
        
        internalOperation = operation
        self.database.add(operation)
    }
    
    override public func cancel() {
        internalOperation?.cancel()
        super.cancel()
    }
}
