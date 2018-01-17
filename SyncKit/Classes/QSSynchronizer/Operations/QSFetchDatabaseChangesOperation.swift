//
//  FetchDatabaseChangesOperation.swift
//  Pods
//
//  Created by Manuel Entrena on 18/05/2018.
//

import Foundation
import CloudKit

@objc
public class QSFetchDatabaseChangesOperation: QSCloudKitSynchronizerOperation {
    
    let database: CKDatabase
    let databaseToken: CKServerChangeToken?
    let completion: (CKServerChangeToken?, [CKRecordZoneID], [CKRecordZoneID]) -> ()
    
    var changedZoneIDs = [CKRecordZoneID]()
    var deletedZoneIDs = [CKRecordZoneID]()
    var operation: CKFetchDatabaseChangesOperation?
    
    @objc public init(database: CKDatabase, databaseToken: CKServerChangeToken?, completion: @escaping (CKServerChangeToken?, [CKRecordZoneID], [CKRecordZoneID]) -> ()) {
        self.databaseToken = databaseToken
        self.database = database
        self.completion = completion
        super.init()
    }
    
    override public func start() {
        super.start()

        let databaseChangesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseToken)
        databaseChangesOperation.fetchAllChanges = true

        databaseChangesOperation.recordZoneWithIDChangedBlock = { zoneID in
            self.changedZoneIDs.append(zoneID)
        }

        databaseChangesOperation.recordZoneWithIDWasDeletedBlock = { zoneID in
            self.deletedZoneIDs.append(zoneID)
        }

        databaseChangesOperation.fetchDatabaseChangesCompletionBlock = { serverChangeToken, moreComing, operationError in

            if !moreComing {
                if operationError == nil {
                    self.completion(serverChangeToken, self.changedZoneIDs, self.deletedZoneIDs)
                }

                self.finish(error: operationError)
            }
        }

        operation = databaseChangesOperation
        database.add(databaseChangesOperation)
    }
    
    override public func cancel() {
        operation?.cancel()
        super.cancel()
    }
}
