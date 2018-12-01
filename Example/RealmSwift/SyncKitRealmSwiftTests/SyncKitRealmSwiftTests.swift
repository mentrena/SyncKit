//
//  SyncKitRealmSwiftTests.swift
//  SyncKitRealmSwiftTests
//
//  Created by Manuel Entrena on 29/08/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import XCTest
import RealmSwift
import CloudKit
import SyncKit
@testable import SyncKitRealmSwiftExample

class SyncKitRealmSwiftTests: XCTestCase, RealmSwiftAdapterDelegate {
    
    var customMergePolicyBlock: ((_ adapter: RealmSwiftAdapter, _ changes: [String: Any], _ object: Object) -> ())?
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: Utilities
    
    func realmSwiftAdapter(_ adapter: RealmSwiftAdapter, gotChanges changes: [String : Any], object: Object) {
        
        customMergePolicyBlock?(adapter, changes, object)
    }
    
    func realmWith(identifier: String) -> Realm {
        
        var configuration = Realm.Configuration()
        configuration.inMemoryIdentifier = identifier
        configuration.objectTypes = [QSCompany.self, QSEmployee.self]
        return try! Realm(configuration: configuration)
    }
    
    func persistenceConfigurationWith(identifier: String) -> Realm.Configuration {
        
        var configuration = RealmSwiftAdapter.defaultPersistenceConfiguration()
        configuration.inMemoryIdentifier = identifier
        return configuration
    }
    
    func waitForHasChangesNotification(from adapter: RealmSwiftAdapter) {
        
        let myExpectation = expectation(description: "Has changes notification arrived")
        let observer = NotificationCenter.default.addObserver(forName: RealmSwiftAdapter.hasChangesNotification, object: adapter, queue: OperationQueue.main) { (notification) in
            
            myExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        NotificationCenter.default.removeObserver(observer)
    }
    
    @discardableResult
    func insertDefaultCompany(realm: Realm) -> QSCompany {
        
        return insertCompany(values: ["identifier": "1", "name": "company1", "sortIndex": 1], realm: realm)
    }
    
    @discardableResult
    func insertCompany(values: [String: Any], realm: Realm) -> QSCompany {
        
        let company = QSCompany(value: values)
        realm.beginWrite()
        realm.add(company)
        try? realm.commitWrite()
        return company
    }
    
    @discardableResult
    func insertDefaultEmployee(company: QSCompany, realm: Realm) -> QSEmployee {
        
        return insertEmployee(values: ["identifier": "employee1", "name": "employee", "company": company], realm: realm)
    }
    
    @discardableResult
    func insertEmployee(values: [String: Any], realm: Realm) -> QSEmployee {
        
        let employee = QSEmployee(value: values)
        realm.beginWrite()
        realm.add(employee)
        try? realm.commitWrite()
        return employee
    }
    
    func syncAdapterAndWait(_ adapter: QSModelAdapter) {
        
        let exp = expectation(description: "synced")
        fullySync(adapter: adapter) { (uploaded, deleted, error) in
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func realmAdapter(targetConfiguration: Realm.Configuration, persistenceConfiguration: Realm.Configuration) -> RealmSwiftAdapter {
        
        return RealmSwiftAdapter(persistenceRealmConfiguration: persistenceConfiguration, targetRealmConfiguration: targetConfiguration, recordZoneID: CKRecordZone.ID(zoneName: "zone", ownerName: "owner"))
    }
    
    func fullySync(adapter: QSModelAdapter, completion: @escaping ([CKRecord], [CKRecord.ID], Error?) -> ()) {
        
        adapter.prepareForImport()
        let recordsToUpload = adapter.recordsToUpload(withLimit: 1000)
        let recordIDsToDelete = adapter.recordIDsMarkedForDeletion(withLimit: 1000)
        adapter.didUploadRecords(recordsToUpload)
        adapter.didDelete(recordIDsToDelete)
        adapter.persistImportedChanges { (error) in
            adapter.didFinishImportWithError(nil)
            completion(recordsToUpload, recordIDsToDelete, error)
        }
    }
    
    func fullySync(adapter: QSModelAdapter, downloaded: [CKRecord], deleted: [CKRecord.ID], completion: @escaping ([CKRecord], [CKRecord.ID], Error?) -> ()) {
        
        adapter.prepareForImport()
        adapter.saveChanges(in: downloaded)
        adapter.deleteRecords(with: deleted)
        
        adapter.persistImportedChanges { (error) in
            var recordsToUpload = [CKRecord]()
            var recordIdsToDelete = [CKRecord.ID]()
            if error == nil {
                recordsToUpload = adapter.recordsToUpload(withLimit: 1000)
                recordIdsToDelete = adapter.recordIDsMarkedForDeletion(withLimit: 1000)
                adapter.didUploadRecords(recordsToUpload)
                adapter.didDelete(recordIdsToDelete)
            }
            adapter.didFinishImportWithError(error)
            completion(recordsToUpload, recordIdsToDelete, error)
        }
    }
    
    // MARK: Tests
    
    func testRecordsToUploadWithLimit_initialSync_returnsRecord() {
        
        let realm = realmWith(identifier: "t1")
        insertCompany(values: ["identifier": "1", "name": "company1", "sortIndex": 1], realm: realm)
        
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p1"))
        
        adapter.prepareForImport()
        let records = adapter.recordsToUpload(withLimit: 10)
        adapter.didFinishImportWithError(nil)
        
        XCTAssertTrue(records.count > 0)
        let record = records.first!
        XCTAssertTrue(record["name"] as? String == "company1")
    }
    
    func testRecordsToUpload_changedObject_returnsRecordWithChanges() {
        
        let realm = realmWith(identifier: "t2")
        let company = insertCompany(values: ["identifier": "1", "name": "company1", "sortIndex": 1], realm: realm)
        
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p2"))
        
        let exp = expectation(description: "synced")
        fullySync(adapter: adapter) { (uploaded, deleted, error) in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        realm.beginWrite()
        company.name = "name 2"
        try! realm.commitWrite()
        
        waitForHasChangesNotification(from: adapter)
        
        adapter.prepareForImport()
        let records = adapter.recordsToUpload(withLimit: 10)
        adapter.didFinishImportWithError(nil)
        
        XCTAssertTrue(records.count > 0)
        let record = records.first!
        XCTAssertTrue(record["name"] as? String == "name 2")
    }
    
    func testRecordsToUpload_includesOnlyToOneRelationships() {
        
        let realm = realmWith(identifier: "t3")
        let company = insertCompany(values: ["identifier": "1", "name": "company1", "sortIndex": 1], realm: realm)
        insertEmployee(values: ["identifier": "2", "company": company, "name": "employee1"], realm: realm)
        
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p3"))
        
        let exp = expectation(description: "synced")
        
        var companyRecord: CKRecord!
        var employeeRecord: CKRecord!
        fullySync(adapter: adapter) { (uploaded, deleted, error) in
            
            for record in uploaded {
                if record.recordID.recordName.hasPrefix("QSCompany") {
                    companyRecord = record
                } else if record.recordID.recordName.hasPrefix("QSEmployee") {
                    employeeRecord = record
                }
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertNotNil(employeeRecord["company"]);
        XCTAssertNil(companyRecord["employees"]);
    }
    
    func testRecordsMarkedForDeletion_deletedObject_returnsRecordID() {
        
        let realm = realmWith(identifier: "t4")
        let company = insertCompany(values: ["identifier": "1", "name": "company1", "sortIndex": 1], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p4"))
        
        let exp = expectation(description: "synced")
        fullySync(adapter: adapter) { (_, _, _) in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        realm.beginWrite()
        realm.delete(company)
        try! realm.commitWrite()
        
        waitForHasChangesNotification(from: adapter)
        
        adapter.prepareForImport()
        let records = adapter.recordIDsMarkedForDeletion(withLimit: 100)
        adapter.didFinishImportWithError(nil)
        
        XCTAssertTrue(records.count > 0)
        XCTAssertTrue(records.first!.recordName == "QSCompany.1")
    }
    
    func testDeleteRecordWithID_deletesCorrespondingObject() {
        
        let realm = realmWith(identifier: "t5")
        insertCompany(values: ["identifier": "1", "name": "company1", "sortIndex": 1], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p5"))
        
        let exp = expectation(description: "synced")
        var objectRecord: CKRecord!
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            objectRecord = uploaded.first!
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        let exp2 = expectation(description: "merged changes")
        fullySync(adapter: adapter, downloaded: [], deleted: [objectRecord.recordID]) { (_, _, _) in
            exp2.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        let objects = realm.objects(QSCompany.self)
        XCTAssertTrue(objects.count == 0)
    }
    
    func testSaveChangesInRecord_existingObject_updatesObject() {
        
        let realm = realmWith(identifier: "t6")
        let company = insertCompany(values: ["identifier": "1", "name": "company1", "sortIndex": 1], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p6"))
        
        let exp = expectation(description: "synced")
        var objectRecord: CKRecord?
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            objectRecord = uploaded.first
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        objectRecord!["name"] = "name 2" as NSString
        
        let exp2 = expectation(description: "merged changes")
        
        adapter.prepareForImport()
        adapter.saveChanges(in: [objectRecord!])
        adapter.persistImportedChanges { (_) in
            exp2.fulfill()
        }
        adapter.didFinishImportWithError(nil)
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(company.name == "name 2")
    }
    
    func testSaveChangesInRecord_newObject_insertsObject() {
        
        let realm = realmWith(identifier: "t7")
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p7"))
        
        let objectRecord = CKRecord(recordType: "QSCompany", recordID: CKRecord.ID(recordName: "QSCompany.1"))
        objectRecord["name"] = "new company" as NSString
        objectRecord["identifier"] = "1" as NSString
        objectRecord["sortIndex"] = NSNumber(value: 1)
        
        let exp = expectation(description: "merged changes")
        
        adapter.prepareForImport()
        adapter.saveChanges(in: [objectRecord])
        adapter.persistImportedChanges { (_) in
            exp.fulfill()
        }
        adapter.didFinishImportWithError(nil)
        
        waitForExpectations(timeout: 1, handler: nil)
        
        let objects = realm.objects(QSCompany.self)
        XCTAssertTrue(objects.count == 1)
        let company = objects.first!
        XCTAssertTrue(company.name == "new company")
        XCTAssertTrue(company.identifier == "1")
    }
    
    func testSaveChangesInRecord_missingProperty_setsPropertyToNil() {
        
        let realm = realmWith(identifier: "t8")
        let company = insertCompany(values: ["identifier": "1", "name": "company1", "sortIndex": 1], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p8"))
        
        let exp = expectation(description: "synced")
        var objectRecord: CKRecord?
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            objectRecord = uploaded.first
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        objectRecord!["name"] = nil
        
        let exp2 = expectation(description: "merged changes")
        
        adapter.prepareForImport()
        adapter.saveChanges(in: [objectRecord!])
        adapter.persistImportedChanges { (_) in
            exp2.fulfill()
        }
        adapter.didFinishImportWithError(nil)
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertNil(company.name)
    }
    
    func testSaveChangesInRecord_missingRelationshipProperty_setsPropertyToNil() {
        
        let realm = realmWith(identifier: "t9")
        let company = insertDefaultCompany(realm: realm)
        let employee = insertDefaultEmployee(company: company, realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p9"))
        
        let exp = expectation(description: "synced")
        var objectRecord: CKRecord?
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            for record in uploaded {
                if record.recordID.recordName.hasPrefix("QSEmployee") {
                    objectRecord = record
                }
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        objectRecord!["company"] = nil
        
        let exp2 = expectation(description: "merged changes")
        
        adapter.prepareForImport()
        adapter.saveChanges(in: [objectRecord!])
        adapter.persistImportedChanges { (_) in
            exp2.fulfill()
        }
        adapter.didFinishImportWithError(nil)
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertNil(employee.company)
    }
    
    func testSaveChangesInRecord_missingToManyRelationshipProperty_doesNothing() {
        
        let realm = realmWith(identifier: "t10")
        let company = insertDefaultCompany(realm: realm)
        insertDefaultEmployee(company: company, realm: realm)
        
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p10"))
        
        let exp = expectation(description: "synced")
        var companyRecord: CKRecord?
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            for record in uploaded {
                if record.recordID.recordName.hasPrefix("QSCompany") {
                    companyRecord = record
                }
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        companyRecord!["employees"] = nil
        
        let exp2 = expectation(description: "merged changes")
        
        adapter.prepareForImport()
        adapter.saveChanges(in: [companyRecord!])
        adapter.persistImportedChanges { (_) in
            exp2.fulfill()
        }
        adapter.didFinishImportWithError(nil)
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(company.employees.count == 1)
    }
    
    func testSaveChangesInRecords_ignoresPrimaryKeyField() {
        
        let realm = realmWith(identifier: "t11")
        let company = insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p11"))
        
        let exp = expectation(description: "synced")
        var objectRecord: CKRecord?
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            objectRecord = uploaded.first
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        objectRecord!["identifier"] = "new identifier" as NSString
        objectRecord!["name"] = "name 2" as NSString
        
        let exp2 = expectation(description: "merged changes")
        
        adapter.prepareForImport()
        adapter.saveChanges(in: [objectRecord!])
        adapter.persistImportedChanges { (_) in
            exp2.fulfill()
        }
        adapter.didFinishImportWithError(nil)
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(company.name == "name 2")
        XCTAssertTrue(company.identifier == "1")
    }
    
    // MARK:- Asset
    
    
    func testRecordToUpload_dataProperty_uploadedAsAsset() {
        
        let realm = realmWith(identifier: "t40")
        _ = insertEmployee(values: ["identifier": "e1", "name": "employee1", "photo": NSData()], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p40"))
        
        let exp = expectation(description: "synced")
        var objectRecord: CKRecord?
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            objectRecord = uploaded.first
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    
        let asset = objectRecord?["photo"] as? CKAsset
    
        XCTAssertNotNil(asset)
        XCTAssertNotNil(asset?.fileURL)
    }
    
    func testRecordToUpload_dataProperty_forceDataType_uploadedAsData() {
        
        let realm = realmWith(identifier: "t44")
        _ = insertEmployee(values: ["identifier": "e1", "name": "employee1", "photo": NSData()], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p44"))
        adapter.forceDataTypeInsteadOfAsset = true
        
        let exp = expectation(description: "synced")
        var objectRecord: CKRecord?
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            objectRecord = uploaded.first
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        let photo = objectRecord?["photo"] as? NSData
        
        XCTAssertNotNil(photo)
    }
    
    func testRecordToUpload_dataPropertyNil_nilsProperty() {
        
        let realm = realmWith(identifier: "t41")
        let employee = insertEmployee(values: ["identifier": "e1", "name": "employee1", "photo": NSData()], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p41"))
        
        let exp = expectation(description: "synced")
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        try! realm.write {
            employee.photo = nil
        }
        
        var objectRecord: CKRecord?
        
        let exp2 = expectation(description: "synced")
        fullySync(adapter: adapter) { (uploaded, _, _) in
            objectRecord = uploaded.first
            exp2.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        let asset = objectRecord?["photo"] as? CKAsset
        
        XCTAssertNil(asset)
    }
    
    func testSaveChangesInRecord_assetProperty_updatesData() {
        
        let realm = realmWith(identifier: "t42")
        let employee = insertEmployee(values: ["identifier": "e1", "name": "employee1"], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p42"))
        
        let exp = expectation(description: "synced")
        var objectRecord: CKRecord?
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            objectRecord = uploaded.first
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        let data = Data(count: 8)
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory() + "test")
        try! data.write(to: fileURL)
        let asset = CKAsset(fileURL: fileURL)
        objectRecord?["photo"] = asset
        
        let exp2 = expectation(description: "synced")
        
        fullySync(adapter: adapter, downloaded: [objectRecord!], deleted: []) { (_, _, _) in
            exp2.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        try! FileManager.default.removeItem(at: fileURL)
        
        XCTAssertNotNil(employee.photo);
        XCTAssertEqual(employee.photo?.count, 8);
    }
    
    func testSaveChangesInRecord_assetPropertyNil_nilsData() {
        
        let realm = realmWith(identifier: "t43")
        let employee = insertEmployee(values: ["identifier": "e1", "name": "employee1", "photo": NSData()], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p43"))
        
        let exp = expectation(description: "synced")
        var objectRecord: CKRecord?
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            objectRecord = uploaded.first
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        objectRecord?["photo"] = nil
        
        let exp2 = expectation(description: "synced")
        
        fullySync(adapter: adapter, downloaded: [objectRecord!], deleted: []) { (_, _, _) in
            exp2.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertNil(employee.photo)
    }
    
    // MARK: -
    
    func testSync_multipleObjects_preservesRelationships() {
        
        let realm = realmWith(identifier: "t12")
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p12"))
        
        let companyRecord = CKRecord(recordType: "QSCompany", recordID: CKRecord.ID(recordName: "QSCompany.1"))
        companyRecord["name"] = "new company" as NSString
        companyRecord["identifier"] = "1" as NSString
        companyRecord["sortIndex"] = NSNumber(value: 1)
        
        let employeeRecord = CKRecord(recordType: "QSEmployee", recordID: CKRecord.ID(recordName: "QSEmployee.1"))
        employeeRecord["name"] = "new employee" as NSString
        employeeRecord["identifier"] = "2" as NSString
        employeeRecord["sortIndex"] = NSNumber(value: 1)
        employeeRecord["company"] = CKRecord.Reference(recordID: companyRecord.recordID, action: .none)
        
        let exp = expectation(description: "merged changes")
        
        adapter.prepareForImport()
        adapter.saveChanges(in: [employeeRecord, companyRecord])
        adapter.persistImportedChanges { (_) in
            exp.fulfill()
        }
        adapter.didFinishImportWithError(nil)
        
        waitForExpectations(timeout: 1, handler: nil)
        
        let objects = realm.objects(QSCompany.self)
        XCTAssertTrue(objects.count == 1)
        let company = objects.first!
        XCTAssertTrue(company.name == "new company")
        XCTAssertTrue(company.employees.count == 1)
        let employee = company.employees.first!
        XCTAssertTrue(employee.name == "new employee")
    }
    
    func testRecordsToUpload_changedObject_changesIncludeOnlyChangedProperties() {
        
        let realm = realmWith(identifier: "t13")
        let company = insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p13"))
        
        let exp = expectation(description: "synced")
        fullySync(adapter: adapter) { (_, _, _) in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        realm.beginWrite()
        company.name = "name 2"
        try! realm.commitWrite()
        
        waitForHasChangesNotification(from: adapter)
        
        adapter.prepareForImport()
        let records = adapter.recordsToUpload(withLimit: 10)
        adapter.didFinishImportWithError(nil)
        
        XCTAssertTrue(records.count > 0);
        let record = records.first!;
        XCTAssertTrue(record["name"] as! String == "name 2")
        XCTAssertNil(record["sortIndex"])
    }
    
    func testHasRecordID_missingObject_returnsNO() {
        
        let realm = realmWith(identifier: "t14")
        insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p14"))
        
        let exp = expectation(description: "synced")
        fullySync(adapter: adapter) { (uploaded, _, _) in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertFalse(adapter.hasRecordID(CKRecord.ID(recordName: "missing")))
    }
    
    func testHasRecordID_existingObject_returnsYES() {
        
        let realm = realmWith(identifier: "t15")
        insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p15"))
        
        let exp = expectation(description: "synced")
        var objectRecord: CKRecord?
        fullySync(adapter: adapter) { (uploaded, _, _) in
            objectRecord = uploaded.first!
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(adapter.hasRecordID(objectRecord!.recordID))
    }
    
    func testHasChanges_noChanges_returnsNO() {
        
        let realm = realmWith(identifier: "t16")
        insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p16"))
        let exp = expectation(description: "synced")
        
        fullySync(adapter: adapter) { (_, _, _) in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertFalse(adapter.hasChanges())
    }
    
    func testHasChanges_objectChanged_returnsYES() {
        
        let realm = realmWith(identifier: "t16")
        let company = insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p16"))
        let exp = expectation(description: "synced")
        
        fullySync(adapter: adapter) { (_, _, _) in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertFalse(adapter.hasChanges())
        
        realm.beginWrite()
        company.name = "name 2"
        try! realm.commitWrite()
        waitForHasChangesNotification(from: adapter)
        
        XCTAssertTrue(adapter.hasChanges())
    }
    
    func testHasChanges_afterSuccessfulSync_returnsNO() {
        let realm = realmWith(identifier: "t17")
        let company = insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p17"))
        
        syncAdapterAndWait(adapter)
        
        XCTAssertFalse(adapter.hasChanges())
        
        realm.beginWrite()
        company.name = "name 2"
        try! realm.commitWrite()
        
        waitForHasChangesNotification(from: adapter)
        
        XCTAssertTrue(adapter.hasChanges())
        
        let exp2 = expectation(description: "synced")
        
        fullySync(adapter: adapter) { (_, _, _) in
            exp2.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertFalse(adapter.hasChanges())
    }
    
    func testInit_insertedObject_objectIsTracked() {
        
        let realm = realmWith(identifier: "t18")
        
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p18"))
        
        syncAdapterAndWait(adapter)
        
        let company = insertDefaultCompany(realm: realm)
        
        waitForHasChangesNotification(from: adapter)
        syncAdapterAndWait(adapter)
        
        realm.beginWrite()
        company.name = "name 2"
        try! realm.commitWrite()
        
        waitForHasChangesNotification(from: adapter)
        
        let exp = expectation(description: "synced")
        
        var record: CKRecord?
        fullySync(adapter: adapter) { (uploaded, _, _) in
            record = uploaded.first
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertNotNil(record)
        XCTAssertTrue(record!["name"] as! String == "name 2")
    }
    
    func testRecordsToUpload_partialUploadSuccess_stillReturnsPendingRecords() {
        
        let realm = realmWith(identifier: "t19")
        insertCompany(values: ["identifier": "1", "name": "company1", "sortIndex": 1], realm: realm)
        insertCompany(values: ["identifier": "2", "name": "company2", "sortIndex": 2], realm: realm)
        
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p19"))
        
        let exp = expectation(description: "synced")
        
        adapter.prepareForImport()
        let recordsToUpload = adapter.recordsToUpload(withLimit: 100)
        adapter.didUploadRecords([recordsToUpload.first!])
        adapter.persistImportedChanges { (_) in
            adapter.didFinishImportWithError(nil)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        let recordsToUploadAfterSync = adapter.recordsToUpload(withLimit: 100)
        
        XCTAssertTrue(recordsToUpload.count == 2)
        XCTAssertTrue(recordsToUploadAfterSync.count == 1)
    }
    
    func testRecordsToUpload_doesNotIncludeObjectsWithOnlyToManyRelationshipChanges() {
        
        let realm = realmWith(identifier: "t20")
        let company = insertDefaultCompany(realm: realm)
        let employee1 = insertEmployee(values: ["identifier": "e1", "name": "employee1", "sortIndex": NSNumber(value: 1)], realm: realm)
        let employee2 = insertEmployee(values: ["identifier": "e2", "name": "employee2", "sortIndex": NSNumber(value: 2)], realm: realm)
        
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p20"))
        
        syncAdapterAndWait(adapter)
        
        realm.beginWrite()
        employee1.company = company
        employee2.company = company
        try! realm.commitWrite()
        
        waitForHasChangesNotification(from: adapter)
        
        adapter.prepareForImport()
        let records = adapter.recordsToUpload(withLimit: 10)
        adapter.didFinishImportWithError(nil)
        
        var companyRecord: CKRecord?
        let employeeRecords = NSMutableSet()
        for record in records {
            if record.recordType == "QSCompany" {
                companyRecord = record
            } else if record.recordType == "QSEmployee" {
                employeeRecords.add(record)
            }
        }
        
        XCTAssertTrue(records.count == 2)
        XCTAssertTrue(employeeRecords.count == 2)
        XCTAssertNil(companyRecord)
    }
    
    func testRecordsToUpload_whenRecordWasDownloadedForObject_usesCorrectRecordVersion() {
        
        let realm = realmWith(identifier: "t21")
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p21"))
        
        let data = try! Data(contentsOf: Bundle(for: SyncKitRealmSwiftTests.self).url(forResource: "QSCompany.1739C6A5-C07E-48A5-B83E-AB07694F23DF", withExtension: "")!)
        let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
        let record = CKRecord(coder: unarchiver)
        unarchiver.finishDecoding()
        
        let recordChangeTag = record?.recordChangeTag
        
        record?["name"] = "new company" as NSString
        record?["sortIndex"] = NSNumber(value: 1)
        
        let exp = expectation(description: "merged changes")
        
        adapter.prepareForImport()
        adapter.saveChanges(in: [record!])
        adapter.persistImportedChanges { (_) in
            exp.fulfill()
            adapter.didFinishImportWithError(nil)
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        realm.refresh()
        
        // Now change object so it produces a record to upload
        
        let company = realm.objects(QSCompany.self).first!
        
        realm.beginWrite()
        company.name = "another name"
        try! realm.commitWrite()
        
        waitForHasChangesNotification(from: adapter)
        
        adapter.prepareForImport()
        let records = adapter.recordsToUpload(withLimit: 10)
        adapter.didFinishImportWithError(nil)
        
        let uploadedRecord = records.first!
        XCTAssertEqual(uploadedRecord.recordChangeTag, recordChangeTag)
    }
    
    func testRecordsToUpload_doesNotIncludePrimaryKey() {
        
        let realm = realmWith(identifier: "t22")
        let company = insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p22"))
        
        syncAdapterAndWait(adapter)
        
        realm.beginWrite()
        company.name = "name 2"
        try! realm.commitWrite()
        
        waitForHasChangesNotification(from: adapter)
        
        adapter.prepareForImport()
        let records = adapter.recordsToUpload(withLimit: 10)
        adapter.didFinishImportWithError(nil)
        
        XCTAssertTrue(records.count > 0)
        XCTAssertNil(records.first!["identifier"])
    }
    
    func testSaveChangesInRecord_existingUniqueObject_updatesObject() {
        
        let realm = realmWith(identifier: "t23")
        let company = insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p23"))
        
        var objectRecord: CKRecord?
        let exp = expectation(description: "synced")
        fullySync(adapter: adapter) { (uploaded, _, _) in
            objectRecord = uploaded.first
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        objectRecord!["name"] = "name 2" as NSString
        
        let exp2 = expectation(description: "merged changes")
        
        adapter.prepareForImport()
        adapter.saveChanges(in: [objectRecord!])
        adapter.persistImportedChanges { (_) in
            exp2.fulfill()
            adapter.didFinishImportWithError(nil)
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(company.name == "name 2")
    }
    
    func testRecordsToUpload_uniqueObjectsWithSameID_mapsObjectsToSameRecord() {
        
        let realm = realmWith(identifier: "t24")
        insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p24"))
        
        let realm2 = realmWith(identifier: "t24-2")
        insertDefaultCompany(realm: realm2)
        let adapter2 = realmAdapter(targetConfiguration: realm2.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p24-2"))
        
        adapter.prepareForImport()
        let records = adapter.recordsToUpload(withLimit: 10)
        adapter.didFinishImportWithError(nil)
        
        adapter2.prepareForImport()
        let records2 = adapter2.recordsToUpload(withLimit: 10)
        adapter2.didFinishImportWithError(nil)
        
        XCTAssertTrue(records.count == 1)
        XCTAssertTrue(records2.count == 1)
        
        XCTAssertTrue(records.first!.recordID.recordName == records2.first!.recordID.recordName)
    }
    
    func testSync_uniqueObjectsWithSameID_updatesObjectCorrectly() {
        
        let realm = realmWith(identifier: "t25")
        let company = insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p25"))
        
        let realm2 = realmWith(identifier: "t25-2")
        let company2 = insertCompany(values: ["identifier": company.identifier, "name": "company2", "sortIndex": NSNumber(value: 2)], realm: realm2)
        let adapter2 = realmAdapter(targetConfiguration: realm2.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p25-2"))
        
        let exp = expectation(description: "synced")
        
        fullySync(adapter: adapter) { (uploaded, deleted, _) in
            
            self.fullySync(adapter: adapter2, downloaded: uploaded, deleted: deleted, completion: { (_, _, _) in
                
                exp.fulfill()
            })
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(company2.name == "company1")
    }
    
    func testSync_serverMergePolicy_prioritizesDownloadedChanges() {
        
        let realm = realmWith(identifier: "t26")
        let company = insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p26"))
        
        let realm2 = realmWith(identifier: "t26-2")
        
        let company2 = insertCompany(values: ["identifier": company.identifier, "name": "company2", "sortIndex": 2], realm: realm2)
        
        let adapter2 = realmAdapter(targetConfiguration: realm2.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p26-2"))
        adapter2.mergePolicy = QSModelAdapterMergePolicy.server
        
        let exp = expectation(description: "synced")
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            
            self.fullySync(adapter: adapter2, downloaded: uploaded, deleted: [], completion: { (_, _, _) in
                exp.fulfill()
            })
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(company2.name == "company1")
    }
    
    func testSync_clientMergePolicy_prioritizesLocalChanges() {
        
        let realm = realmWith(identifier: "t27")
        let company = insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p27"))
        
        let realm2 = realmWith(identifier: "t27-2")
        
        let company2 = insertCompany(values: ["identifier": company.identifier, "name": "company2", "sortIndex": 2], realm: realm2)
        
        let adapter2 = realmAdapter(targetConfiguration: realm2.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p27-2"))
        adapter2.mergePolicy = QSModelAdapterMergePolicy.client
        
        let exp = expectation(description: "synced")
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            
            self.fullySync(adapter: adapter2, downloaded: uploaded, deleted: [], completion: { (_, _, _) in
                exp.fulfill()
            })
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(company2.name == "company2")
    }
    
    func testSync_customMergePolicy_callsDelegateForResolution() {
        
        let realm = realmWith(identifier: "t28")
        let company = insertDefaultCompany(realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p28"))
        
        let realm2 = realmWith(identifier: "t28-2")
        let company2 = insertCompany(values: ["identifier": company.identifier, "name": "company2", "sortIndex": 2], realm: realm2)
        let adapter2 = realmAdapter(targetConfiguration: realm2.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p28-2"))
        
        adapter2.mergePolicy = QSModelAdapterMergePolicy.custom
        adapter2.delegate = self
        
        let exp = expectation(description: "synced")
        
        var calledCustomMergePolicyMethod = false
        customMergePolicyBlock = { (adapter, changes, object) in
            if adapter == adapter2 && object is QSCompany && changes["name"] as! String == "company1" {
                calledCustomMergePolicyMethod = true
                object.setValue("company3", forKey: "name")
            }
        }
        
        fullySync(adapter: adapter) { (uploaded, _, _) in
            self.fullySync(adapter: adapter2, downloaded: uploaded, deleted: [], completion: { (_, _, _) in
                exp.fulfill()
            })
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(calledCustomMergePolicyMethod)
        XCTAssertTrue(company2.name == "company3")
    }
    
    // MARK: - Sharing
    
    func testRecordForObjectWithIdentifier_noObject_returnsNil() {
        
        let realm = realmWith(identifier: "t50")
        let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                               persistenceConfiguration: persistenceConfigurationWith(identifier: "p50"))
        let record = adapter.record(for: nil)
        XCTAssertNil(record)
    }
    
    func testRecordForObjectWithIdentifier_existingObject_returnsRecord() {
        
        let realm = realmWith(identifier: "t51")
        let company = insertCompany(values: ["identifier": NSUUID().uuidString, "name": "company1", "sortIndex": 1], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                               persistenceConfiguration: persistenceConfigurationWith(identifier: "p51"))
        let record = adapter.record(for: company)
        XCTAssertNotNil(record)
        XCTAssertTrue(record!.recordID.recordName.hasPrefix("QSCompany"))
    }
    
    func testShareForObjectWithIdentifier_noShare_returnsNil() {
        
        let realm = realmWith(identifier: "t52")
        let company = insertCompany(values: ["identifier": NSUUID().uuidString, "name": "company1", "sortIndex": 1], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                               persistenceConfiguration: persistenceConfigurationWith(identifier: "p52"))
        let share = adapter.share(for: company)
        XCTAssertNil(share)
    }

    func testShareForObjectWithIdentifier_saveShareCalled_returnsShare() {
        
        let realm = realmWith(identifier: "t53")
        let company = insertCompany(values: ["identifier": NSUUID().uuidString, "name": "company1", "sortIndex": 1], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                               persistenceConfiguration: persistenceConfigurationWith(identifier: "p53"))
        let record = adapter.record(for: company)
        let share = CKShare(rootRecord: record!)
        
        adapter.save(share, for: company)
        
        let share2 = adapter.share(for: company)
        XCTAssertNotNil(share2)
    }

    func testShareForObjectWithIdentifier_shareDeleted_returnsNil() {
        
        let realm = realmWith(identifier: "t54")
        let company = insertCompany(values: ["identifier": NSUUID().uuidString, "name": "company1", "sortIndex": 1], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                               persistenceConfiguration: persistenceConfigurationWith(identifier: "p54"))
        let record = adapter.record(for: company)
        let share = CKShare(rootRecord: record!)
        
        adapter.save(share, for: company)
        
        XCTAssertNotNil(adapter.share(for: company))
        
        adapter.deleteShare(for: company)
        
        XCTAssertNil(adapter.share(for: company))
    }

    func testSaveChangesInRecords_includesShare_savesObjectAndShare() {
        
        let realm = realmWith(identifier: "t55")
        let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                               persistenceConfiguration: persistenceConfigurationWith(identifier: "p55"))
        
        let companyRecord = CKRecord(recordType: "QSCompany", recordID: CKRecord.ID(recordName: "QSCompany.com1"))
        companyRecord["name"] = "new company" as NSString
        
        let shareRecord = CKShare(rootRecord: companyRecord, shareID: CKRecord.ID(recordName: "QSShare.forCompany"))
        
        let expectation = self.expectation(description: "synced")
        fullySync(adapter: adapter, downloaded: [companyRecord, shareRecord], deleted: []) { (_, _, _) in
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        let company = realm.objects(QSCompany.self).first
        let share = adapter.share(for: company!)
        
        XCTAssertNotNil(company)
        XCTAssertNotNil(share)
        XCTAssertTrue(company?.name == "new company")
        XCTAssertTrue(share?.recordID.recordName == "QSShare.forCompany")
    }

    func testDeleteRecordsWithIDs_containsShare_deletesShare() {
        
        let realm = realmWith(identifier: "t56")
        let company = insertCompany(values: ["identifier": NSUUID().uuidString, "name": "company1", "sortIndex": 1], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                               persistenceConfiguration: persistenceConfigurationWith(identifier: "p56"))
        
        let record = adapter.record(for: company)
        let shareID = CKRecord.ID(recordName: "CKShare.identifier", zoneID: record!.recordID.zoneID)
        let share = CKShare(rootRecord: record!, shareID: shareID)
        
        adapter.save(share, for: company)
        
        let savedShare = adapter.share(for: company)
        XCTAssertNotNil(savedShare)
        
        let expectation = self.expectation(description: "synced")
        fullySync(adapter: adapter, downloaded: [], deleted: [shareID]) { (_, _, _) in
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        
        let updatedShare = adapter.share(for: company)
        XCTAssertNil(updatedShare)
    }
    
    func testRecordsToUpload_includesAnyParentRecordsInBatch() {
        let realm = realmWith(identifier: "t57")
        let company = insertCompany(values: ["identifier": "com1", "name": "company1", "sortIndex": 1], realm: realm)
        insertEmployee(values: ["identifier": "emp1", "name": "employee1", "sortIndex": NSNumber(value: 1), "company": company], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                   persistenceConfiguration: persistenceConfigurationWith(identifier: "p57"))
        
        adapter.prepareForImport()
        let records = adapter.recordsToUpload(withLimit: 1)
        adapter.didFinishImportWithError(nil)
        
        XCTAssertEqual(records.count, 2);
        let companyRecord = records.first { $0.recordID.recordName.contains("com1") }
        let employeeRecord = records.first { $0.recordID.recordName.contains("emp1") }
        XCTAssertNotNil(companyRecord)
        XCTAssertNotNil(employeeRecord)
    }
    
    func testRecordsToUpdateParentRelationshipsForRoot_returnsRecords() {
        
        let realm = realmWith(identifier: "t60")
        let company = insertCompany(values: ["identifier": "com1", "name": "company1", "sortIndex": 1], realm: realm)
        let company2 = insertCompany(values: ["identifier": "com2", "name": "company2", "sortIndex": 1], realm: realm)
        insertEmployee(values: ["identifier": "emp1", "name": "employee1", "sortIndex": NSNumber(value: 1), "company": company], realm: realm)
        insertEmployee(values: ["identifier": "emp2", "name": "employee2", "sortIndex": NSNumber(value: 1), "company": company], realm: realm)
        insertEmployee(values: ["identifier": "emp3", "name": "employee3", "sortIndex": NSNumber(value: 1), "company": company2], realm: realm)
        insertEmployee(values: ["identifier": "emp4", "name": "employee4", "sortIndex": NSNumber(value: 1), "company": company2], realm: realm)
        let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                   persistenceConfiguration: persistenceConfigurationWith(identifier: "p60"))

        let records =  adapter.recordsToUpdateParentRelationships(forRoot: company)
        XCTAssertEqual(records!.count, 3)
        for record in records! {
            XCTAssertTrue(record.recordID.recordName.contains("com1") ||
                record.recordID.recordName.contains("emp1") ||
                record.recordID.recordName.contains("emp2"))
        }
    }
    
    // MARK: - 0.6.0
    
    func testOldToken_preserved() {
        
        let realm = realmWith(identifier: "t70")
        
        // Delete any leftover data
        let synchronizer = QSCloudKitSynchronizer.cloudKitPrivateSynchronizer(containerName: "container", configuration: realm.configuration)
        let adapter = synchronizer.modelAdapters().first as? RealmSwiftAdapter
        
        let realmURL = adapter!.persistenceRealmConfiguration.fileURL!
        let realmURLs = [
            realmURL,
            realmURL.appendingPathExtension("lock"),
            realmURL.appendingPathExtension("note"),
            realmURL.appendingPathExtension("management")
        ]
        for URL in realmURLs {
            do {
                try FileManager.default.removeItem(at: URL)
            } catch {
                // handle error
            }
        }
        
        // Test
        
        let data = try! Data(contentsOf: Bundle(for: SyncKitRealmSwiftTests.self).url(forResource: "serverChangeToken.AQAAAWPa1DUC", withExtension: nil)!)
        let token = NSKeyedUnarchiver.unarchiveObject(with: data) as! CKServerChangeToken
        UserDefaults.standard.set(data, forKey: "containerQSCloudKitFetchChangesServerTokenKey")
        
        let synchronizer2 = QSCloudKitSynchronizer.cloudKitPrivateSynchronizer(containerName: "container", configuration: realm.configuration)
        let adapterToken = synchronizer2.modelAdapters().first?.serverChangeToken()
        
        XCTAssertNotNil(token);
        XCTAssertTrue(adapterToken == token);
        XCTAssertNil(UserDefaults.standard.object(forKey: "containerQSCloudKitFetchChangesServerTokenKey"))
    }
}
