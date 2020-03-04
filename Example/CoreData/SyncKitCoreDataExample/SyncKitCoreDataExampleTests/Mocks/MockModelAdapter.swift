//
//  MockModelAdapter.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 12/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import SyncKit
import CloudKit

class MockModelAdapter: NSObject, ModelAdapter {
    
    private var toUpload = [QSObject]()
    private var toDelete = [QSObject]()
    
    var objects = [QSObject]()
    var sharesByIdentifier = [String: CKShare]()
    var recordsByIdentifier = [String: CKRecord]()
    
    func markForUpload(_ objects: [QSObject]) {
        toUpload = objects
    }
    
    func markForDeletion(_ objects: [QSObject]) {
        toDelete = objects
    }
    
    var hasChanges: Bool {
        return !toUpload.isEmpty || !toDelete.isEmpty
    }
    
    var prepareToImportCalled = false
    func prepareToImport() {
        prepareToImportCalled = true
    }
    
    var saveChangesCalled = false
    func saveChanges(in records: [CKRecord]) {
        saveChangesCalled = true
        records.forEach {
            self.saveChanges(in: $0)
        }
    }
    
    func saveChanges(in record: CKRecord) {
        if let first = objects.first(where: { $0.identifier == record.recordID.recordName }) {
            first.save(record: record)
        } else {
            let object = QSObject(record: record)
            objects.append(object)
        }
    }
    
    var deleteRecordsCalled = false
    func deleteRecords(with recordIDs: [CKRecord.ID]) {
        deleteRecordsCalled = true
        recordIDs.forEach {
            self.deleteRecords(with: $0)
        }
    }
    
    func deleteRecords(with recordID: CKRecord.ID) {
        if let index = objects.firstIndex(where: { $0.identifier == recordID.recordName }) {
            objects.remove(at: index)
        }
    }
    
    var persistImportedChangesCalled = false
    func persistImportedChanges(completion: @escaping (Error?) -> ()) {
        persistImportedChangesCalled = true
        completion(nil)
    }
    
    var recordsToUploadCalled = false
    func recordsToUpload(limit: Int) -> [CKRecord] {
        recordsToUploadCalled = true
        return toUpload.prefix(limit).map { $0.record(with: self.recordZoneID) }
    }
    
    var didUploadCalled = false
    func didUpload(savedRecords: [CKRecord]) {
        didUploadCalled = true
        savedRecords.forEach { record in
            if let index = self.toUpload.firstIndex(where: { $0.identifier == record.recordID.recordName }) {
                self.toUpload.remove(at: index)
            }
        }
    }
    
    var recordIDsMarkedForDeletionCalled = false
    func recordIDsMarkedForDeletion(limit: Int) -> [CKRecord.ID] {
        recordIDsMarkedForDeletionCalled = true
        return toDelete.prefix(limit).map { $0.recordID(zoneID: self.recordZoneID) }
    }
    
    var didDeleteCalled = false
    func didDelete(recordIDs: [CKRecord.ID]) {
        didDeleteCalled = true
        deleteRecords(with: recordIDs)
    }
    
    var hasRecordIDCalled = false
    func hasRecordID(_ recordID: CKRecord.ID) -> Bool {
        hasRecordIDCalled = true
        return objects.contains(where: { $0.identifier == recordID.recordName })
    }
    
    var didFinishImportCalled = false
    func didFinishImport(with error: Error?) {
        didFinishImportCalled = true
        toDelete.removeAll()
        toUpload.removeAll()
    }
    
    var recordZoneIDValue: CKRecordZone.ID!
    var recordZoneID: CKRecordZone.ID {
        return recordZoneIDValue
    }
    
    var token: CKServerChangeToken?
    var serverChangeToken: CKServerChangeToken? {
        return token
    }
    
    func saveToken(_ token: CKServerChangeToken?) {
        self.token = token
    }
    
    var deleteChangeTrackingCalledClosure: (() -> ())?
    var deleteChangeTrackingCalled = false
    func deleteChangeTracking() {
        deleteChangeTrackingCalled = true
        deleteChangeTrackingCalledClosure?()
    }
    
    var mergePolicy: MergePolicy = .server
    
    func record(for object: AnyObject) -> CKRecord? {
        guard let object = object as? QSObject,
            objects.contains(object) else {
            return nil
        }
        return object.record(with: recordZoneID)
    }
    
    func share(for object: AnyObject) -> CKShare? {
        return nil
    }
    
    func save(share: CKShare, for object: AnyObject) {
        
    }
    
    func deleteShare(for object: AnyObject) {
        
    }
    
    var recordsToUpdateParentRelationshipForRootValue: [CKRecord]?
    func recordsToUpdateParentRelationshipsForRoot(_ object: AnyObject) -> [CKRecord] {
        return recordsToUpdateParentRelationshipForRootValue ?? []
    }
}
