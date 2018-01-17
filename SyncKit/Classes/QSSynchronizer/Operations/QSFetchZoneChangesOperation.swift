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
    @objc public var deletedRecordIDs = [CKRecordID]()
    @objc public var serverChangeToken: CKServerChangeToken?
    @objc public var error: Error?
    @objc public var moreComing: Bool = false
}

public class QSFetchZoneChangesOperation: QSCloudKitSynchronizerOperation {
    
    let database: CKDatabase
    let zoneIDs: [CKRecordZoneID]
    var zoneChangeTokens: [CKRecordZoneID: CKServerChangeToken]
    let modelVersion: Int
    let deviceIdentifier: String
    let completion: ([CKRecordZoneID: QSFetchZoneChangesOperationZoneResult]) -> ()
    let desiredKeys: [String]?
    
    var zoneResults = [CKRecordZoneID: QSFetchZoneChangesOperationZoneResult]()
    
    let dispatchQueue = DispatchQueue(label: "fetchZoneChangesDispatchQueue")
    var operation: CKFetchRecordZoneChangesOperation?
    
    @objc public init(database: CKDatabase,
                      zoneIDs: [CKRecordZoneID],
                      zoneChangeTokens: [CKRecordZoneID: CKServerChangeToken],
                      modelVersion: Int,
                      deviceIdentifier: String,
                      desiredKeys: [String]?,
                      completion: @escaping ([CKRecordZoneID: QSFetchZoneChangesOperationZoneResult]) -> ()) {
        
        self.database = database
        self.zoneIDs = zoneIDs
        self.zoneChangeTokens = zoneChangeTokens
        self.modelVersion = modelVersion
        self.deviceIdentifier = deviceIdentifier
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
    
    func performFetchOperation(with zones: [CKRecordZoneID]) {
        
        var higherModelVersionFound = false
        var zoneOptions = [CKRecordZoneID: CKFetchRecordZoneChangesOptions]()
        
        for zoneID in zones {
            let options = CKFetchRecordZoneChangesOptions()
            options.previousServerChangeToken = zoneChangeTokens[zoneID]
            options.desiredKeys = desiredKeys
            zoneOptions[zoneID] = options
        }
        
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zones, optionsByRecordZoneID: zoneOptions)
        operation.fetchAllChanges = false
        
        operation.recordChangedBlock = { record in
            
            self.dispatchQueue.async {
                if self.deviceIdentifier != record[QSCloudKitDeviceUUIDKey] as? String {
                    
                    if let version = record[QSCloudKitModelCompatibilityVersionKey] as? Int,
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
                if let error = operationError {
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
        
        self.operation = operation
        self.database.add(operation)
    }
    
    override public func cancel() {
        operation?.cancel()
        super.cancel()
    }
}
