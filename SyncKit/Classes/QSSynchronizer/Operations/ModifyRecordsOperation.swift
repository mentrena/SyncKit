//
//  ModifyRecordsOperation.swift
//  Pods
//
//  Created by Manuel Entrena on 06/09/2020.
//

import Foundation
import CloudKit

class ModifyRecordsOperation: CloudKitSynchronizerOperation {
    let database: CloudKitDatabaseAdapter
    let records: [CKRecord]?
    let recordIDsToDelete: [CKRecord.ID]?
    
    let completion: ([CKRecord]?, [CKRecord.ID]?, [CKRecord], Error?) -> ()
    
    init(database: CloudKitDatabaseAdapter, records: [CKRecord]?, recordIDsToDelete: [CKRecord.ID]?, completion: @escaping ([CKRecord]?, [CKRecord.ID]?, [CKRecord], Error?) -> ()) {
        self.database = database
        self.records = records
        self.recordIDsToDelete = recordIDsToDelete
        self.completion = completion
    }
    
    private var conflictedRecords = [CKRecord]()
    
    let dispatchQueue = DispatchQueue(label: "modifyRecordsDispatchQueue")
    weak var internalOperation: CKModifyRecordsOperation?
        
    override func start() {
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: recordIDsToDelete)
        
        operation.perRecordCompletionBlock = { record, error in
            if let error = error as? CKError,
                error.code == CKError.serverRecordChanged,
                let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord{
                self.conflictedRecords.append(serverRecord)
            }
        }
        operation.modifyRecordsCompletionBlock = { saved, deleted, operationError in
            
            self.completion(saved, deleted, self.conflictedRecords, operationError)
        }
        
        internalOperation = operation
        database.add(operation)
    }
    
    override func cancel() {
        internalOperation?.cancel()
        super.cancel()
    }
}
