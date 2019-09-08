//
//  CoreDataAdapterTests.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 15/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import XCTest
import SyncKit
import CoreData
import CloudKit

class CoreDataAdapterTests: XCTestCase {
    
    var targetCoreDataStack: CoreDataStack!
    var persistenceCoreDataStack: CoreDataStack!
    var recordZoneID: CKRecordZone.ID!
    
    var didCallRequestContextSave = false
    var didCallImportChanges = false
    
    var customMergePolicyBlock: ((CoreDataAdapter, NSManagedObject, [String: Any])->())?
    
    override func setUp() {
        super.setUp()
        
        didCallImportChanges = false
        didCallRequestContextSave = false
        recordZoneID = CKRecordZone.ID(zoneName: "zone", ownerName: "owner")
        targetCoreDataStack = coreDataStack(modelName: "QSExample")
        persistenceCoreDataStack = coreDataStack(model: CoreDataAdapter.persistenceModel, concurrencyType: .privateQueueConcurrencyType)
    }
    
    override func tearDown() {
        persistenceCoreDataStack = nil
        targetCoreDataStack = nil
        super.tearDown()
    }
    
    func testPersistImportedChanges_callsDelegate() {
        insertCompany(name: "1", identifier: "1", context: targetCoreDataStack.managedObjectContext)
        let adapter = createAdapter()
        let expectation = self.expectation(description: "synced")
        
        fullySync(adapter: adapter) { (_, _, _) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertTrue(didCallImportChanges)
        XCTAssertTrue(didCallRequestContextSave)
    }
    
    func testRecordsToUploadWithLimit_initialSync_returnsRecord() {
        insertCompany(name: "name", identifier: "id1", context: targetCoreDataStack.managedObjectContext)
        let adapter = createAdapter()
        adapter.prepareToImport()
        let records = adapter.recordsToUpload(limit: 10)
        adapter.didFinishImport(with: nil)
        XCTAssertEqual(records.count, 1)
        let record = records.first
        XCTAssertEqual(record?["name"], "name")
    }
    
    func testRecordsToUpload_changedObject_returnsRecordWithChanges() {
        let company = insertCompany(name: "name", identifier: "id1", context: targetCoreDataStack.managedObjectContext)
        let adapter = createAdapter()
        waitUntilSynced(adapter: adapter)
        
        company.name = "name 2"
        try! targetCoreDataStack.managedObjectContext.save()
        
        adapter.prepareToImport()
        let records = adapter.recordsToUpload(limit: 10)
        adapter.didFinishImport(with: nil)
        
        XCTAssertEqual(records.first?["name"], "name 2")
    }
    
    func testRecordsToUpload_onlyIncludesToOneRelationships() {
        let company = insertCompany(name: "name", identifier: "id1", context: targetCoreDataStack.managedObjectContext)
        insertEmployee(name: "employee 1", identifier: "em1",company: company, context: targetCoreDataStack.managedObjectContext)
        let adapter = createAdapter()
        let results = waitUntilSynced(adapter: adapter)
        let companyRecord = results.updated.first { $0.recordID.recordName.hasPrefix("QSCompany") }
        let employeeRecord = results.updated.first { $0.recordID.recordName.hasPrefix("QSEmployee") }
        XCTAssertNotNil(companyRecord)
        XCTAssertNil(companyRecord?["employees"])
        XCTAssertNotNil(employeeRecord?["company"])
    }
    
    func testRecordsMarkedForDeletion_deletedObject_returnsRecordID() {
        let company = insertCompany(name: "name", identifier: "id1", context: targetCoreDataStack.managedObjectContext)
        let adapter = createAdapter()
        waitUntilSynced(adapter: adapter)
        
        targetCoreDataStack.managedObjectContext.performAndWait {
            self.targetCoreDataStack.managedObjectContext.delete(company)
            try! self.targetCoreDataStack.managedObjectContext.save()
        }
        
        adapter.prepareToImport()
        let records = adapter.recordIDsMarkedForDeletion(limit: 10)
        adapter.didFinishImport(with: nil)
        
        XCTAssertTrue(records.first!.recordName.contains("id1"))
    }
    
    func testDeleteRecordWithID_deletesCorrespondingObject() {
        insertCompany(name: "name", identifier: "id1", context: targetCoreDataStack.managedObjectContext)
        let adapter = createAdapter()
        let uploadedRecord = waitUntilSynced(adapter: adapter).updated.first
        waitUntilSynced(adapter: adapter, deleted: [uploadedRecord!.recordID])
        let objects = try! targetCoreDataStack.managedObjectContext.executeFetchRequest(entityName: "QSCompany") as! [QSCompany]
        XCTAssertEqual(objects.count, 0)
    }
    
    func testSaveChangesInRecord_existingObject_updatesObject() {
        let company = insertCompany()
        let adapter = createAdapter()
        let uploadedRecord = waitUntilSynced(adapter: adapter).updated.first!
        uploadedRecord["name"] = "name 2"
        waitUntilSynced(adapter: adapter, downloaded: [uploadedRecord])
        targetCoreDataStack.managedObjectContext.refresh(company, mergeChanges: false)
        XCTAssertEqual(company.name, "name 2")
    }
    
    func testSaveChangesInRecord_newObject_insertsObject() {
        let adapter = createAdapter()
        let record = CKRecord(recordType: "QSCompany",
                              recordID: CKRecord.ID(recordName: "QSCompany.com1",
                                                    zoneID: recordZoneID))
        record["name"] = "new company"
        waitUntilSynced(adapter: adapter, downloaded: [record])
        let objects = try? targetCoreDataStack.managedObjectContext.executeFetchRequest(entityName: "QSCompany") as? [QSCompany]
        let company = objects?.first
        XCTAssertNotNil(company)
        XCTAssertEqual(company?.name, "new company")
        XCTAssertNotNil(company?.identifier, "com1")
    }
    
    func testSaveChangesInRecord_missingProperty_setsPropertyToNil() {
        let company = insertCompany()
        let adapter = createAdapter()
        let record = waitUntilSynced(adapter: adapter).updated.first!
        record["name"] = nil
        waitUntilSynced(adapter: adapter, downloaded: [record])
        targetCoreDataStack.managedObjectContext.refresh(company, mergeChanges: false)
        XCTAssertNil(company.name)
    }
    
    func testSaveChangesInRecord_missingRelationshipProperty_setsPropertyToNil() {
        let company = insertCompany()
        let employee = insertEmployee(company: company)
        let adapter = createAdapter()
        let employeeRecord = waitUntilSynced(adapter: adapter).updated.first { $0.recordID.recordName.contains("QSEmployee") }!
        employeeRecord["company"] = nil
        waitUntilSynced(adapter: adapter, downloaded: [employeeRecord])
        targetCoreDataStack.managedObjectContext.refresh(employee, mergeChanges: false)
        XCTAssertNil(employee.company)
    }
    
    func testSaveChangesInRecord_missingToManyRelationshipProperty_doesNothing() {
        let company = insertCompany()
        insertEmployee(company: company)
        let adapter = createAdapter()
        let companyRecord = waitUntilSynced(adapter: adapter).updated.first { $0.recordID.recordName.contains("QSCompany") }!
        companyRecord["employees"] = nil
        waitUntilSynced(adapter: adapter, downloaded: [companyRecord])
        targetCoreDataStack.managedObjectContext.refresh(company, mergeChanges: false)
        XCTAssertTrue(company.employees!.count > 0)
    }
    
    func testSync_multipleObjects_preservesRelationships() {
        let adapter = createAdapter()
        let companyRecord = CKRecord(recordType: "QSCompany", recordID: CKRecord.ID(recordName: "QSCompany.com1", zoneID: recordZoneID))
        companyRecord["name"] = "new company"
        let employeeRecord = CKRecord(recordType: "QSEmployee", recordID: CKRecord.ID(recordName: "QSEmployee.em1", zoneID: recordZoneID))
        employeeRecord["name"] = "new employee"
        employeeRecord["company"] = CKRecord.Reference(recordID: companyRecord.recordID, action: .none)
        
        waitUntilSynced(adapter: adapter, downloaded: [employeeRecord, companyRecord])
        
        let objects = try? targetCoreDataStack.managedObjectContext.executeFetchRequest(entityName: "QSCompany") as? [QSCompany]
        XCTAssertEqual(objects?.count, 1)
        let company = objects?.first
        XCTAssertEqual(company?.name, "new company")
        XCTAssertEqual(company?.employees?.count, 1)
        let employee = company?.employees?.anyObject() as? QSEmployee
        XCTAssertEqual(employee?.name, "new employee")
    }
    
    func testHasRecordID_missingObject_returnsNO() {
        insertCompany()
        let adapter = createAdapter()
        waitUntilSynced(adapter: adapter)
        XCTAssertFalse(adapter.hasRecordID(CKRecord.ID(recordName: "missing", zoneID: recordZoneID)))
    }
    
    func testHasRecordID_existingObject_returnsYES() {
        insertCompany()
        let adapter = createAdapter()
        let record = waitUntilSynced(adapter: adapter).updated.first
        XCTAssertTrue(adapter.hasRecordID(record!.recordID))
    }
    
    func testHasChanges_noChanges_returnsNO() {
        insertCompany()
        let adapter = createAdapter()
        waitUntilSynced(adapter: adapter)
        XCTAssertFalse(adapter.hasChanges)
    }
    
    func testHasChanges_objectChanged_returnsYES() {
        let company = insertCompany()
        let adapter = createAdapter()
        waitUntilSynced(adapter: adapter)
        
        company.name = "name 2"
        try! targetCoreDataStack.managedObjectContext.save()
        
        XCTAssertTrue(adapter.hasChanges)
    }
    
    func testHasChanges_afterSuccessfulSync_returnsNO() {
        let company = insertCompany()
        let adapter = createAdapter()
        company.name = "name 2"
        try! targetCoreDataStack.managedObjectContext.save()
        waitUntilSynced(adapter: adapter)
        XCTAssertFalse(adapter.hasChanges)
    }
    
    func testDeleteChangeTracking_deletesStore() {
        let adapter = createAdapter()
        adapter.deleteChangeTracking()
        XCTAssertNil(persistenceCoreDataStack.managedObjectContext)
    }
    
    func testRecordsToUpload_partialUploadSuccess_stillReturnsPendingRecords() {
        insertCompany(name: "name 1", identifier: "com1")
        insertCompany(name: "name 2", identifier: "com2")
        let adapter = createAdapter()
        
        let expectation = self.expectation(description: "synced")
        adapter.prepareToImport()
        let recordsToUpload = adapter.recordsToUpload(limit: 10)
        adapter.didUpload(savedRecords: [recordsToUpload.first!])
        adapter.persistImportedChanges { (_) in
            adapter.didFinishImport(with: nil)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        let recordsToUploadAfterSync = adapter.recordsToUpload(limit: 10)
        XCTAssertEqual(recordsToUpload.count, 2)
        XCTAssertEqual(recordsToUploadAfterSync.count, 1)
    }
    
    func testRecordsToUpload_doesNotIncludeObjectsWithOnlyToManyRelationshipChanges() {
        let company = insertCompany()
        let emp1 = insertEmployee(name: "employee1",
                                  identifier: "em1",
                                  company: company)
        let emp2 = insertEmployee(name: "employee2",
                                  identifier: "em2",
                                  company: company)
        let adapter = createAdapter()
        waitUntilSynced(adapter: adapter)
        company.employees = NSSet(array: [emp1, emp2])
        emp1.name = "employee 1-2"
        try! targetCoreDataStack.managedObjectContext.save()
        let uploaded = waitUntilSynced(adapter: adapter).updated
        let companyRecord = uploaded.first { $0.recordID.recordName.contains("QSCompany") }
        let employeeRecord = uploaded.first { $0.recordID.recordName.contains("QSEmployee") }
        XCTAssertNil(companyRecord)
        XCTAssertNotNil(employeeRecord)
    }
    
    func testRecordsToUpload_whenRecordWasDownloadedForObject_usesCorrectRecordVersion() {
        let adapter = createAdapter()
        let record = QSCompany.stubbedRecord()
        let recordChangeTag = record.recordChangeTag
        
        record["name"] = "new company"
        
        waitUntilSynced(adapter: adapter, downloaded: [record])
        
        let objects = try? targetCoreDataStack.managedObjectContext.executeFetchRequest(entityName: "QSCompany") as? [QSCompany]
        let company = objects?.first
        company?.name = "another name"
        try! targetCoreDataStack.managedObjectContext.save()
        
        let uploadedRecord = waitUntilSynced(adapter: adapter).updated.first
        XCTAssertEqual(uploadedRecord?.recordChangeTag, recordChangeTag)
    }
}

// MARK: - CKAsset
extension CoreDataAdapterTests {
    func testRecordToUpload_dataProperty_uploadedAsAsset() {
        let employee = insertEmployee(company: nil)
        employee.photo = Data() as NSData
        try! targetCoreDataStack.managedObjectContext.save()
        let adapter = createAdapter()
        let record = waitUntilSynced(adapter: adapter).updated.first
        let asset = record?["photo"] as? CKAsset
        XCTAssertNotNil(asset?.fileURL)
    }
    
    func testRecordToUpload_dataProperty_forceDataType_uploadedAsData() {
        let employee = insertEmployee(company: nil)
        employee.photo = Data() as NSData
        try! targetCoreDataStack.managedObjectContext.save()
        let adapter = createAdapter()
        adapter.forceDataTypeInsteadOfAsset = true
        let record = waitUntilSynced(adapter: adapter).updated.first
        let asset = record?["photo"] as? Data
        XCTAssertNotNil(asset)
    }
    
    func testRecordToUpload_dataPropertyNil_nilsProperty() {
        let employee = insertEmployee(company: nil)
        employee.photo = Data() as NSData
        try! targetCoreDataStack.managedObjectContext.save()
        let adapter = createAdapter()
        waitUntilSynced(adapter: adapter)
        employee.photo = nil
        try! targetCoreDataStack.managedObjectContext.save()
        let record = waitUntilSynced(adapter: adapter).updated.first
        let asset = record?["photo"] as? CKAsset
        XCTAssertNotNil(record)
        XCTAssertNil(asset)
    }
    
    func testSaveChangesInRecord_assetProperty_updatesData() {
        let employee = insertEmployee(company: nil)
        try! targetCoreDataStack.managedObjectContext.save()
        let adapter = createAdapter()
        let record = waitUntilSynced(adapter: adapter).updated.first!
        let data = NSData(bytes: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], length: 8)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test")
        data.write(to: fileURL, atomically: true)
        let asset = CKAsset(fileURL: fileURL)
        record["photo"] = asset
        waitUntilSynced(adapter: adapter, downloaded: [record])
        try! FileManager.default.removeItem(at: fileURL)
        targetCoreDataStack.managedObjectContext.refresh(employee, mergeChanges: false)
        XCTAssertNotNil(employee.photo)
        XCTAssertEqual(employee.photo?.length, 8)
    }
    
    func testSaveChangesInRecord_assetPropertyNil_nilsData() {
        let employee = insertEmployee(company: nil)
        employee.photo = Data() as NSData
        try! targetCoreDataStack.managedObjectContext.save()
        let adapter = createAdapter()
        let record = waitUntilSynced(adapter: adapter).updated.first!
        record["photo"] = nil
        waitUntilSynced(adapter: adapter, downloaded: [record])
        targetCoreDataStack.managedObjectContext.refresh(employee, mergeChanges: false)
        XCTAssertNil(employee.photo)
    }
}

// MARK: - Unique identifiers
extension CoreDataAdapterTests {
    func testSaveChangesInRecord_existingUniqueObject_updatesObject() {
        let company = insertCompany()
        let adapter = createAdapter()
        let record = waitUntilSynced(adapter: adapter).updated.first!
        record["name"] = "name 2"
        waitUntilSynced(adapter: adapter, downloaded: [record])
        targetCoreDataStack.managedObjectContext.refresh(company, mergeChanges: false)
        XCTAssertEqual(company.name, "name 2")
    }
    
    func testRecordsToUpload_uniqueObjectsWithSameID_mapsObjectsToSameRecord() {
        let target2 = coreDataStack(modelName: "QSExample")
        let persistence2 = coreDataStack(model: CoreDataAdapter.persistenceModel, concurrencyType: .privateQueueConcurrencyType)
        // Use same identifiers
        let company = insertCompany(name: "name 1", identifier: "com1")
        insertCompany(name: "name 2", identifier: company.identifier!, context: target2.managedObjectContext)
        let adapter = createAdapter()
        let adapter2 = createAdapter(persistenceStack: persistence2, targetContext: target2.managedObjectContext)
        let records = waitUntilSynced(adapter: adapter).updated
        let records2 = waitUntilSynced(adapter: adapter2).updated
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records2.count, 1)
        XCTAssertEqual(records.first?.recordID.recordName, records2.first?.recordID.recordName)
    }
    
    func testSync_uniqueObjectsWithSameID_updatesObjectCorrectly() {
        let target2 = coreDataStack(modelName: "QSExample")
        let persistence2 = coreDataStack(model: CoreDataAdapter.persistenceModel, concurrencyType: .privateQueueConcurrencyType)
        // Use same identifiers
        let company = insertCompany(name: "name 1", identifier: "com1")
        let company2 = insertCompany(name: "name 2", identifier: company.identifier!, context: target2.managedObjectContext)
        let adapter = createAdapter()
        let adapter2 = createAdapter(persistenceStack: persistence2, targetContext: target2.managedObjectContext)
        let records = waitUntilSynced(adapter: adapter).updated
        waitUntilSynced(adapter: adapter2, downloaded: records)
        target2.managedObjectContext.refresh(company2, mergeChanges: false)
        XCTAssertEqual(company2.name, "name 1")
    }
    
    func testRecordsToUpload_doesNotIncludePrimaryKey() {
        insertCompany()
        let adapter = createAdapter()
        let record = waitUntilSynced(adapter: adapter).updated.first!
        XCTAssertNotNil(record["name"])
        XCTAssertNil(record["identifier"])
    }
    
    func testSaveChangesInRecords_ignoresPrimaryKeyField() {
        let company = insertCompany(name: "name 1", identifier: "com1")
        let adapter = createAdapter()
        let record = waitUntilSynced(adapter: adapter).updated.first!
        record["identifier"] = "fake identifier"
        record["name"] = "name 2"
        waitUntilSynced(adapter: adapter, downloaded: [record])
        targetCoreDataStack.managedObjectContext.refresh(company, mergeChanges: false)
        XCTAssertEqual(company.name, "name 2")
        XCTAssertEqual(company.identifier, "com1")
    }
}

// MARK: - Merge policies
extension CoreDataAdapterTests {
    func testSync_serverMergePolicy_prioritizesDownloadedChanges() {
        let target2 = coreDataStack(modelName: "QSExample")
        let persistence2 = coreDataStack(model: CoreDataAdapter.persistenceModel, concurrencyType: .privateQueueConcurrencyType)
        let company = insertCompany(name: "name 1", identifier: "com1", context: targetCoreDataStack.managedObjectContext)
        let company2 = insertCompany(name: "name 2", identifier: company.identifier!, context: target2.managedObjectContext)
        let adapter = createAdapter()
        let adapter2 = createAdapter(persistenceStack: persistence2, targetContext: target2.managedObjectContext)
        let records = waitUntilSynced(adapter: adapter).updated
        waitUntilSynced(adapter: adapter2, downloaded: records)
        target2.managedObjectContext.refresh(company2, mergeChanges: false)
        XCTAssertEqual(company2.name, "name 1")
    }
    
    func testSync_clientMergePolicy_prioritizesLocalChanges() {
        let target2 = coreDataStack(modelName: "QSExample")
        let persistence2 = coreDataStack(model: CoreDataAdapter.persistenceModel, concurrencyType: .privateQueueConcurrencyType)
        let company = insertCompany(name: "name 1", identifier: "com1", context: targetCoreDataStack.managedObjectContext)
        let company2 = insertCompany(name: "name 2", identifier: company.identifier!, context: target2.managedObjectContext)
        let adapter = createAdapter()
        let adapter2 = createAdapter(persistenceStack: persistence2, targetContext: target2.managedObjectContext)
        adapter2.mergePolicy = .client
        let records = waitUntilSynced(adapter: adapter).updated
        waitUntilSynced(adapter: adapter2, downloaded: records)
        target2.managedObjectContext.refresh(company2, mergeChanges: false)
        XCTAssertEqual(company2.name, "name 2")
    }
    
    func testSync_customMergePolicy_callsDelegateForResolution() {
        let target2 = coreDataStack(modelName: "QSExample")
        let persistence2 = coreDataStack(model: CoreDataAdapter.persistenceModel, concurrencyType: .privateQueueConcurrencyType)
        let company = insertCompany(name: "name 1", identifier: "com1", context: targetCoreDataStack.managedObjectContext)
        let company2 = insertCompany(name: "name 2", identifier: company.identifier!, context: target2.managedObjectContext)
        let adapter = createAdapter()
        let adapter2 = createAdapter(persistenceStack: persistence2, targetContext: target2.managedObjectContext)
        adapter2.conflictDelegate = self
        adapter2.mergePolicy = .custom
        var calledCustomMergePolicyMethod = false
        customMergePolicyBlock = { adapter, object, changes in
            calledCustomMergePolicyMethod = true
            if adapter === adapter2,
                let object = object as? QSCompany,
                changes["name"] != nil {
                object.setValue("name 3", forKey: "name")
            }
        }
        let records = waitUntilSynced(adapter: adapter).updated
        waitUntilSynced(adapter: adapter2, downloaded: records)
        target2.managedObjectContext.refresh(company2, mergeChanges: false)
        XCTAssertEqual(company2.name, "name 3")
        XCTAssertTrue(calledCustomMergePolicyMethod)
    }
}

// MARK: - Other
extension CoreDataAdapterTests {
    func testRecordZoneID_returnsZoneID() {
        let adapter = createAdapter()
        XCTAssertEqual(adapter.recordZoneID.ownerName, "owner")
        XCTAssertEqual(adapter.recordZoneID.zoneName, "zone")
    }
    
    func testServerChangeToken_noToken_returnsNil() {
        let adapter = createAdapter()
        XCTAssertNil(adapter.serverChangeToken)
    }
    
    func testServerChangeToken_savedToken_returnsToken() {
        let adapter = createAdapter()
        let token = CKServerChangeToken.stub()
        adapter.saveToken(token)
        let token2 = adapter.serverChangeToken
        XCTAssertEqual(token, token2)
    }
}

// MARK: - Sharing
extension CoreDataAdapterTests {
    func testRecordForObjectWithIdentifier_existingObject_returnsRecord() {
        let company = insertCompany()
        let adapter = createAdapter()
        let record = adapter.record(for: company)
        XCTAssertNotNil(record)
        XCTAssertTrue(record!.recordID.recordName.contains("QSCompany"))
        XCTAssertTrue(record!.recordID.recordName.contains(company.identifier!))
    }
    
    func testShareForObjectWithIdentifier_noShare_returnsNil() {
        let company = insertCompany()
        let adapter = createAdapter()
        let share = adapter.share(for: company)
        XCTAssertNil(share)
    }
    
    func testShareForObjectWithIdentifier_saveShareCalled_returnsShare() {
        let company = insertCompany()
        let adapter = createAdapter()
        let record = adapter.record(for: company)!
        let share = CKShare(rootRecord: record)
        adapter.save(share: share, for: company)
        let share2 = adapter.share(for: company)
        XCTAssertNotNil(share2)
    }
    
    func testShareForObjectWithIdentifier_shareDeleted_returnsNil() {
        let company = insertCompany()
        let adapter = createAdapter()
        let record = adapter.record(for: company)!
        let share = CKShare(rootRecord: record)
        adapter.save(share: share, for: company)
        adapter.deleteShare(for: company)
        XCTAssertNil(adapter.share(for: company))
    }
    
    func testSaveChangesInRecords_includesShare_savesObjectAndShare() {
        let adapter = createAdapter()
        let companyRecord = CKRecord(recordType: "QSCompany", recordID: CKRecord.ID(recordName: "QSCompany.com1"))
        companyRecord["name"] = "new company"
        let shareRecord = CKShare(rootRecord: companyRecord, shareID: CKRecord.ID(recordName: "QSShare.forCompany"))
        waitUntilSynced(adapter: adapter, downloaded: [companyRecord, shareRecord])
        let company = (try! targetCoreDataStack.managedObjectContext.executeFetchRequest(entityName: "QSCompany") as! [QSCompany]).first!
        let share = adapter.share(for: company)
        XCTAssertNotNil(company)
        XCTAssertNotNil(share)
        XCTAssertEqual(company.name, "new company")
        XCTAssertEqual(share?.recordID.recordName, "QSShare.forCompany")
    }
    
    func testDeleteRecordsWithIDs_containsShare_deletesShare() {
        let company = insertCompany()
        let adapter = createAdapter()
        let record = adapter.record(for: company)!
        let share = CKShare(rootRecord: record, shareID: CKRecord.ID(recordName: "CKShare.identifier", zoneID: recordZoneID))
        adapter.save(share: share, for: company)
        waitUntilSynced(adapter: adapter, deleted: [share.recordID])
        XCTAssertNil(adapter.share(for: company))
    }
    
    func testRecordsToUpdateParentRelationshipsForRoot_returnsRecords() {
        let company = insertCompany(name: "name 1", identifier: "com1")
        let company2 = insertCompany(name: "name 2", identifier: "com2")
        insertEmployee(name: "em1", identifier: "em1", company: company)
        insertEmployee(name: "em2", identifier: "em2", company: company)
        insertEmployee(name: "em3", identifier: "em3", company: company2)
        insertEmployee(name: "em4", identifier: "em4", company: company2)
        let adapter = createAdapter()
        let records = adapter.recordsToUpdateParentRelationshipsForRoot(company)
        XCTAssertEqual(records.count, 3)
        let companyRecord = records.first { $0.recordID.recordName.contains("com1") }
        let empRecord = records.first { $0.recordID.recordName.contains("em1") }
        let emp2Record = records.first { $0.recordID.recordName.contains("em2") }
        XCTAssertNotNil(companyRecord)
        XCTAssertNotNil(empRecord)
        XCTAssertNotNil(emp2Record)
    }
    
    func testRecordsToUpload_includesAnyParentRecordsInBatch() {
        let company = insertCompany()
        insertEmployee(company: company)
        let adapter = createAdapter()
        adapter.prepareToImport()
        let records = adapter.recordsToUpload(limit: 1)
        adapter.didFinishImport(with: nil)
        XCTAssertEqual(records.count, 2)
    }
}

// MARK: - Transformable
extension CoreDataAdapterTests {
    func testRecordsToUploadWithLimit_transformableProperty_usesValueTransformer() {
        QSNamesTransformer.register()
        QSNamesTransformer.resetValues()
        targetCoreDataStack = coreDataStack(modelName: "QSTransformableTestModel")
        
        insert(entityType: "QSTestEntity",
               properties: ["identifier": "identifier",
                            "names": ["1", "2"]],
               context: targetCoreDataStack.managedObjectContext)
        let adapter = createAdapter()
        let records = waitUntilSynced(adapter: adapter).updated
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(QSNamesTransformer.transformedValueCalled)
        XCTAssertFalse(QSNamesTransformer.reverseTransformedValueCalled)
        let transformed = QSNamesTransformer().transformedValue(["1", "2"]) as? NSData
        XCTAssertEqual(records.first?["names"], transformed)
    }
    
    func testSaveChangesInRecords_transformableProperty_usesValueTransformer() {
        QSNamesTransformer.register()
        targetCoreDataStack = coreDataStack(modelName: "QSTransformableTestModel")
        let adapter = createAdapter()
        let record = CKRecord(recordType: "QSTestEntity", recordID: CKRecord.ID(recordName: "QSTestEntity.ent1"))
        record["identifier"] = "ent1"
        record["names"] = QSNamesTransformer().transformedValue(["1", "2", "3"]) as? CKRecordValueProtocol
        
        QSNamesTransformer.resetValues()
        waitUntilSynced(adapter: adapter, downloaded: [record])
        let objects = try! targetCoreDataStack.managedObjectContext.executeFetchRequest(entityName: "QSTestEntity") as? [QSTestEntity]
        XCTAssertEqual(objects?.count, 1)
        let testEntity = objects?.first
        XCTAssertEqual(testEntity?.identifier, "ent1")
        XCTAssertEqual(testEntity?.names, ["1", "2", "3"])
        XCTAssertTrue(QSNamesTransformer.reverseTransformedValueCalled)
        XCTAssertFalse(QSNamesTransformer.transformedValueCalled)
    }
    
    func testRecordsToUploadWithLimit_transformablePropertyNoValueTransformer_usesKeyedArchiver() {
        targetCoreDataStack = coreDataStack(modelName: "QSTransformableTestModel")
        
        insert(entityType: "QSTestEntity2",
               properties: ["identifier": "identifier",
                            "names": ["1", "2"]],
               context: targetCoreDataStack.managedObjectContext)
        let adapter = createAdapter()
        let records = waitUntilSynced(adapter: adapter).updated
        XCTAssertEqual(records.count, 1)
        let record = records.first!
        let names = (try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: record["names"]!)) as? [String]
        XCTAssertEqual(names, ["1", "2"])
    }
    
    func testSaveChangesInRecords_transformablePropertyNoValueTransformer_usesKeyedArchiver() {
        targetCoreDataStack = coreDataStack(modelName: "QSTransformableTestModel")
        let adapter = createAdapter()
        let record = CKRecord(recordType: "QSTestEntity2", recordID: CKRecord.ID(recordName: "QSTestEntity2.ent1"))
        record["identifier"] = "ent1"
        record["names"] = try? NSKeyedArchiver.archivedData(withRootObject: ["1", "2", "3"], requiringSecureCoding: false)
        
        waitUntilSynced(adapter: adapter, downloaded: [record])
        let objects = try! targetCoreDataStack.managedObjectContext.executeFetchRequest(entityName: "QSTestEntity2") as? [QSTestEntity2]
        XCTAssertEqual(objects?.count, 1)
        let testEntity = objects?.first
        XCTAssertEqual(testEntity?.identifier, "ent1")
        XCTAssertEqual(testEntity?.names, ["1", "2", "3"])
    }
}

extension CoreDataAdapterTests: CoreDataAdapterDelegate, CoreDataAdapterConflictResolutionDelegate {
    func coreDataAdapter(_ adapter: CoreDataAdapter, requestsContextSaveWithCompletion completion: (Error?) -> ()) {
        didCallRequestContextSave = true
        targetCoreDataStack.managedObjectContext.performAndWait {
            try! targetCoreDataStack.managedObjectContext.save()
        }
        completion(nil)
    }
    
    func coreDataAdapter(_ adapter: CoreDataAdapter, didImportChanges importContext: NSManagedObjectContext, completion: (Error?) -> ()) {
        didCallImportChanges = true
        importContext.performAndWait {
            try! importContext.save()
            adapter.targetContext.performAndWait {
                try! adapter.targetContext.save()
            }
        }
        completion(nil)
    }
    
    func coreDataAdapter(_ adapter: CoreDataAdapter, gotChanges changeDictionary: [String : Any], for object: NSManagedObject) {
        customMergePolicyBlock?(adapter, object, changeDictionary)
    }
}

extension CoreDataAdapterTests {
    
    func coreDataStack(modelName: String) -> CoreDataStack {
        let modelURL = Bundle(for: CoreDataAdapterTests.self).url(forResource: modelName, withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        return coreDataStack(model: model)
    }
    
    func coreDataStack(model: NSManagedObjectModel, concurrencyType: NSManagedObjectContextConcurrencyType = .mainQueueConcurrencyType) -> CoreDataStack {
        return CoreDataStack(storeType: NSInMemoryStoreType,
                             model: model,
                             storeURL: nil,
                             concurrencyType: concurrencyType,
                             dispatchImmediately: true)
    }
    
    func createAdapter(persistenceStack: CoreDataStack? = nil, targetContext: NSManagedObjectContext? = nil) -> CoreDataAdapter {
        let persistenceStack: CoreDataStack = persistenceStack ?? persistenceCoreDataStack
        let targetContext: NSManagedObjectContext = targetContext ?? targetCoreDataStack.managedObjectContext
        return CoreDataAdapter(persistenceStack: persistenceStack,
                               targetContext: targetContext,
                               recordZoneID: recordZoneID,
                               delegate: self)
    }
    
    @discardableResult
    func insert(entityType: String, properties: [String: Any], context: NSManagedObjectContext) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: entityType, into: context)
        properties.forEach { (key, value) in
            object.setValue(value, forKey: key)
        }
        try! context.save()
        return object
    }
    
    @discardableResult
    func insertCompany(name: String = "name 1", identifier: String = "com1", context: NSManagedObjectContext? = nil) -> QSCompany {
        let context: NSManagedObjectContext = context ?? targetCoreDataStack.managedObjectContext
        let company = NSEntityDescription.insertNewObject(forEntityName: "QSCompany", into: context) as! QSCompany
        company.name = name
        company.identifier = identifier
        try! context.save()
        return company
    }
    
    @discardableResult
    func insertEmployee(name: String = "employee 1", identifier: String = "em1", company: QSCompany?, context: NSManagedObjectContext? = nil) -> QSEmployee {
        let context: NSManagedObjectContext = context ?? targetCoreDataStack.managedObjectContext
        let employee = NSEntityDescription.insertNewObject(forEntityName: "QSEmployee", into: context) as! QSEmployee
        employee.name = name
        employee.identifier = identifier
        employee.company = company
        try! context.save()
        return employee
    }
    
    @discardableResult
    func waitUntilSynced(adapter: ModelAdapter, downloaded: [CKRecord] = [], deleted: [CKRecord.ID] = []) -> (updated: [CKRecord], deleted: [CKRecord.ID]) {
        let expectation = self.expectation(description: "synced")
        var updatedRecordsResult: [CKRecord]!
        var deletedRecordIDsResult: [CKRecord.ID]!
        fullySync(adapter: adapter, downloaded: downloaded, deleted: deleted) { (updatedRecords, deletedRecordIDs, _) in
            updatedRecordsResult = updatedRecords
            deletedRecordIDsResult = deletedRecordIDs
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        return (updatedRecordsResult ?? [], deletedRecordIDsResult ?? [])
    }
    
    func fullySync(adapter: ModelAdapter, downloaded: [CKRecord] = [], deleted: [CKRecord.ID] = [], completion: (([CKRecord], [CKRecord.ID], Error?)->())?) {
        adapter.prepareToImport()
        adapter.saveChanges(in: downloaded)
        adapter.deleteRecords(with: deleted)
        adapter.persistImportedChanges { (error) in
            guard error == nil else {
                adapter.didFinishImport(with: error)
                completion?([], [], error)
                return
            }
            
            let toUpload = adapter.recordsToUpload(limit: 100)
            adapter.didUpload(savedRecords: toUpload)
            let toDelete = adapter.recordIDsMarkedForDeletion(limit: 100)
            adapter.didDelete(recordIDs: toDelete)
            
            adapter.didFinishImport(with: error)
            completion?(toUpload, toDelete, error)
        }
    }
}
