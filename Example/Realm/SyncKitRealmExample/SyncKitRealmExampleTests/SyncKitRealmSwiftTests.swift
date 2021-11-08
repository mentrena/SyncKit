//
//  SyncKitRealmTests.swift
//  SyncKitRealmTests
//
//  Created by Manuel Entrena on 29/08/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import XCTest
import Realm
import CloudKit
import SyncKit
@testable import SyncKitRealmExample

class SyncKitRealmTests: XCTestCase, RealmAdapterDelegate {
    
    var customMergePolicyBlock: ((_ adapter: RealmAdapter, _ changes: [String: Any], _ object: RLMObject) -> ())?
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: Utilities
    
    func RealmAdapter(_ adapter: RealmAdapter, gotChanges changes: [String : Any], object: RLMObject) {
        
        customMergePolicyBlock?(adapter, changes, object)
    }
    
    func realmWith(identifier: String, keyType: RLMPropertyType = .string) -> RLMRealm {
        
        let configuration = RLMRealmConfiguration()
        configuration.inMemoryIdentifier = identifier
        switch keyType {
        case .string:
            configuration.objectClasses = [QSCompany.self, QSEmployee.self]
        case .int:
            configuration.objectClasses = [QSCompany_Int.self, QSEmployee_Int.self]
        case .objectId:
            configuration.objectClasses = [QSCompany_ObjId.self, QSEmployee_ObjId.self]
        default:
            break
        }
        return try! RLMRealm(configuration: configuration)
    }
    
    func persistenceConfigurationWith(identifier: String) -> RLMRealmConfiguration {
        
        let configuration = SyncKit.RealmAdapter.defaultPersistenceConfiguration()
        configuration.inMemoryIdentifier = identifier
        return configuration
    }
    
    func waitForHasChangesNotification(from adapter: RealmAdapter) {
        
        let myExpectation = expectation(description: "Has changes notification arrived")
        let observer = NotificationCenter.default.addObserver(forName: .ModelAdapterHasChangesNotification, object: adapter, queue: OperationQueue.main) { (notification) in
            
            myExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        NotificationCenter.default.removeObserver(observer)
    }
    
    @discardableResult
    func insertDefaultCompany(realm: RLMRealm) -> QSCompany {
        
        return insertCompany(values: ["identifier": "1", "name": "company1", "sortIndex": 1], realm: realm)
    }
    
    @discardableResult
    func insertCompany(values: [String: Any], realm: RLMRealm) -> QSCompany {
        
        let company = QSCompany(value: values)
        realm.beginWriteTransaction()
        realm.add(company)
        try? realm.commitWriteTransaction()
        return company
    }
    
    @discardableResult
    func insertDefaultEmployee(company: QSCompany, realm: RLMRealm) -> QSEmployee {
        
        return insertEmployee(values: ["identifier": "employee1", "name": "employee", "company": company], realm: realm)
    }
    
    @discardableResult
    func insertEmployee(values: [String: Any], realm: RLMRealm) -> QSEmployee {
        
        let employee = QSEmployee(value: values)
        realm.beginWriteTransaction()
        realm.add(employee)
        try? realm.commitWriteTransaction()
        return employee
    }
    
    @discardableResult
    func insertObject(values: [String: Any], realm: RLMRealm, objectType: RLMObject.Type) -> RLMObject {
        let object = objectType.init()
        object.setValuesForKeys(values)
        realm.beginWriteTransaction()
        realm.add(object)
        try? realm.commitWriteTransaction()
        return object
    }
    
    func syncAdapterAndWait(_ adapter: ModelAdapter) {
        
        let exp = expectation(description: "synced")
        fullySync(adapter: adapter) { (uploaded, deleted, error) in
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func realmAdapter(targetConfiguration: RLMRealmConfiguration, persistenceConfiguration: RLMRealmConfiguration) -> RealmAdapter {
        
        return SyncKit.RealmAdapter(persistenceRealmConfiguration: persistenceConfiguration,
                                    targetRealmConfiguration: targetConfiguration,
                                    recordZoneID: CKRecordZone.ID(zoneName: "zone", ownerName: "owner"))
    }
    
    func fullySync(adapter: ModelAdapter, completion: @escaping ([CKRecord], [CKRecord.ID], Error?) -> ()) {
        
        adapter.prepareToImport()
        let recordsToUpload = adapter.recordsToUpload(limit: 1000)
        let recordIDsToDelete = adapter.recordIDsMarkedForDeletion(limit: 1000)
        adapter.didUpload(savedRecords: recordsToUpload)
        adapter.didDelete(recordIDs: recordIDsToDelete)
        adapter.persistImportedChanges { (error) in
            adapter.didFinishImport(with: nil)
            completion(recordsToUpload, recordIDsToDelete, error)
        }
    }
    
    func fullySync(adapter: ModelAdapter, downloaded: [CKRecord], deleted: [CKRecord.ID], completion: @escaping ([CKRecord], [CKRecord.ID], Error?) -> ()) {
        
        adapter.prepareToImport()
        adapter.saveChanges(in: downloaded)
        adapter.deleteRecords(with: deleted)
        
        adapter.persistImportedChanges { (error) in
            var recordsToUpload = [CKRecord]()
            var recordIdsToDelete = [CKRecord.ID]()
            if error == nil {
                recordsToUpload = adapter.recordsToUpload(limit: 1000)
                recordIdsToDelete = adapter.recordIDsMarkedForDeletion(limit: 1000)
                adapter.didUpload(savedRecords: recordsToUpload)
                adapter.didDelete(recordIDs: recordIdsToDelete)
            }
            adapter.didFinishImport(with: error)
            completion(recordsToUpload, recordIdsToDelete, error)
        }
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
    
    struct TestCase {
        let keyType: RLMPropertyType
        let values: [String: Any]!
        let companyIdentifier: Any
        let companyIdentifier2: Any
        let employeeIdentifier: Any
        let employeeIdentifier2: Any
        init(_ keyType: RLMPropertyType,
             companyIdentifier: Any,
             companyIdentifier2: Any,
             employeeIdentifier: Any,
             employeeIdentifier2: Any,
             _ values: [String: Any] = [:]
        ) {
            self.keyType = keyType
            self.values = values
            self.companyIdentifier = companyIdentifier
            self.employeeIdentifier = employeeIdentifier
            self.companyIdentifier2 = companyIdentifier2
            self.employeeIdentifier2 = employeeIdentifier2
        }
        
        var name: String {
            return String(keyType.rawValue)
        }
        
        var companyType: RLMObject.Type {
            switch keyType {
            case .int:
                return QSCompany_Int.self
            case .objectId:
                return QSCompany_ObjId.self
            case .string: fallthrough
            default:
                return QSCompany.self
            }
        }
        
        var employeeType: RLMObject.Type {
            switch keyType {
            case .int:
                return QSEmployee_Int.self
            case .objectId:
                return QSEmployee_ObjId.self
            case .string: fallthrough
            default:
                return QSEmployee.self
            }
        }
        
        static var defaultCases: [TestCase] {
            return [
                TestCase(.string, companyIdentifier: "1", companyIdentifier2: "2", employeeIdentifier: "10", employeeIdentifier2: "11"),
                TestCase(.int, companyIdentifier: 1, companyIdentifier2: 2, employeeIdentifier: 10, employeeIdentifier2: 11),
                TestCase(.objectId, companyIdentifier: RLMObjectId.generate(), companyIdentifier2: RLMObjectId.generate(), employeeIdentifier: RLMObjectId.generate(), employeeIdentifier2: RLMObjectId.generate())
            ]
        }
    }
    
    func defaultTestObjects(testCase: TestCase, name: String, insertCompany: Bool = true, insertEmployee: Bool = true) -> (realm: RLMRealm, adapter: RealmAdapter, company: RLMObject?, employee: RLMObject?) {
        let realm = realmWith(identifier: "t\(name)_\(testCase.name)", keyType: testCase.keyType)
        var company: RLMObject?
        if insertCompany {
            company = insertObject(values: ["identifier": testCase.companyIdentifier, "name": "company1", "sortIndex": 0], realm: realm, objectType: testCase.companyType)
        }
        var employee: RLMObject?
        if insertEmployee {
            employee = insertObject(values: ["identifier": testCase.employeeIdentifier, "name": "employee", "company": company!, "sortIndex": 0], realm: realm, objectType: testCase.employeeType)
        }
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p\(name)_\(testCase.name)"))
        return (realm, adapter, company, employee)
    }
    
    // MARK: Tests
    
    func testRecordsToUploadWithLimit_initialSync_returnsRecord() {
        
        TestCase.defaultCases.forEach { tc in
            let realm = realmWith(identifier: "t1_\(tc.name)", keyType: tc.keyType)
            insertObject(values: ["identifier": tc.companyIdentifier, "name": "company1", "sortIndex": 1],
                         realm: realm,
                         objectType: tc.companyType)
            
            let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                       persistenceConfiguration: persistenceConfigurationWith(identifier: "p1_\(tc.name)"))
            
            adapter.prepareToImport()
            let records = adapter.recordsToUpload(limit: 10)
            adapter.didFinishImport(with: nil)
            
            XCTAssertTrue(records.count > 0)
            let record = records.first!
            XCTAssertTrue(record["name"] as? String == "company1")
        }
    }
    
    func testRecordsToUpload_changedRLMObject_returnsRecordWithChanges() {
        TestCase.defaultCases.forEach { tc in
            let realm = realmWith(identifier: "t2_\(tc.name)", keyType: tc.keyType)
            let company = insertObject(values: ["identifier": tc.companyIdentifier, "name": "company1"], realm: realm, objectType: tc.companyType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p2_\(tc.name)"))
            
            let exp = expectation(description: "synced")
            fullySync(adapter: adapter) { (uploaded, deleted, error) in
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            realm.beginWriteTransaction()
            company.setValue("name 2", forKey: "name")
            try! realm.commitWriteTransaction()
            
            waitForHasChangesNotification(from: adapter)
            
            adapter.prepareToImport()
            let records = adapter.recordsToUpload(limit: 10)
            adapter.didFinishImport(with: nil)
            
            XCTAssertTrue(records.count > 0)
            let record = records.first!
            XCTAssertTrue(record["name"] as? String == "name 2")
        }
    }
    
    func testRecordsToUpload_includesOnlyToOneRelationships() {
        
        TestCase.defaultCases.forEach { tc in
            let realm = realmWith(identifier: "t3_\(tc.name)", keyType: tc.keyType)
            let company = insertObject(values: ["identifier": tc.companyIdentifier, "name": "company1"], realm: realm, objectType: tc.companyType)
            insertObject(values:  ["identifier": tc.employeeIdentifier, "company": company, "name": "employee1"], realm: realm, objectType: tc.employeeType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p3_\(tc.name)"))
            
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
    }
    
    func testRecordsMarkedForDeletion_deletedRLMObject_returnsRecordID() {
        
        TestCase.defaultCases.forEach { tc in
            let companyId = tc.companyIdentifier
            let realm = realmWith(identifier: "t4_\(tc.name)", keyType: tc.keyType)
            let company = insertObject(values: ["identifier": companyId, "name": "company1"], realm: realm, objectType: tc.companyType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p4_\(tc.name)"))
            
            let exp = expectation(description: "synced")
            fullySync(adapter: adapter) { (_, _, _) in
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            realm.beginWriteTransaction()
            realm.delete(company)
            try! realm.commitWriteTransaction()
            
            waitForHasChangesNotification(from: adapter)
            
            adapter.prepareToImport()
            let records = adapter.recordIDsMarkedForDeletion(limit: 100)
            adapter.didFinishImport(with: nil)
            
            XCTAssertTrue(records.count > 0)
            XCTAssertEqual(records.first!.recordName, "\(String(describing: tc.companyType)).\((companyId as! CustomStringConvertible).description)")
        }
    }
    
    func testDeleteRecordWithID_deletesCorrespondingRLMObject() {
        
        TestCase.defaultCases.forEach { tc in
            let companyId = tc.companyIdentifier
            let realm = realmWith(identifier: "t5_\(tc.name)", keyType: tc.keyType)
            insertObject(values: ["identifier": companyId, "name": "company1"], realm: realm, objectType: tc.companyType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p5_\(tc.name)"))
            
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
            
            let objects = tc.companyType.allObjects(in: realm)
            XCTAssertTrue(objects.count == 0)
        }
    }
    
    func testSaveChangesInRecord_existingRLMObject_updatesRLMObject() {
        
        TestCase.defaultCases.forEach { tc in
            let companyId = tc.companyIdentifier
            let realm = realmWith(identifier: "t6_\(tc.name)", keyType: tc.keyType)
            let company = insertObject(values: ["identifier": companyId, "name": "company1", "sortIndex": 1], realm: realm, objectType: tc.companyType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p6_\(tc.name)"))
            
            let exp = expectation(description: "synced")
            var objectRecord: CKRecord?
            
            fullySync(adapter: adapter) { (uploaded, _, _) in
                objectRecord = uploaded.first
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            objectRecord!["name"] = "name 2" as NSString
            
            let exp2 = expectation(description: "merged changes")
            
            adapter.prepareToImport()
            adapter.saveChanges(in: [objectRecord!])
            adapter.persistImportedChanges { (_) in
                exp2.fulfill()
            }
            adapter.didFinishImport(with: nil)
            
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(company.value(forKey: "name") as? String, "name 2")
        }
    }
    
    func testSaveChangesInRecord_newRLMObject_insertsRLMObject() {
        
        TestCase.defaultCases.forEach { tc in
            let companyId = tc.companyIdentifier
            let stringIdentifier = (companyId as! CustomStringConvertible).description
            let realm = realmWith(identifier: "t7_\(tc.name)", keyType: tc.keyType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p7_\(tc.name)"))
            let objectRecord = CKRecord(recordType: String(describing: tc.companyType),
                                        recordID: CKRecord.ID(recordName: "\(String(describing: tc.companyType)).\(stringIdentifier)"))
            objectRecord["name"] = "new company" as NSString
            objectRecord["identifier"] = stringIdentifier
            objectRecord["sortIndex"] = NSNumber(value: 1)
            
            let exp = expectation(description: "merged changes")
            
            adapter.prepareToImport()
            adapter.saveChanges(in: [objectRecord])
            adapter.persistImportedChanges { (_) in
                exp.fulfill()
            }
            adapter.didFinishImport(with: nil)
            
            waitForExpectations(timeout: 1, handler: nil)
            
            let objects = tc.companyType.allObjects(in: realm)
            XCTAssertTrue(objects.count == 1)
            let company = objects.firstObject()!
            XCTAssertEqual(company.value(forKey: "name") as? String, "new company")
            let objectIdentifier = company.value(forKey: "identifier") as? CustomStringConvertible
            XCTAssertEqual(objectIdentifier?.description, stringIdentifier)
        }
    }
    
    func testSaveChangesInRecord_missingProperty_setsPropertyToNil() {
        
        TestCase.defaultCases.forEach { tc in
            let companyId = tc.companyIdentifier
            let realm = realmWith(identifier: "t8_\(tc.name)", keyType: tc.keyType)
            let company = insertObject(values: ["identifier": companyId, "name": "company1", "sortIndex": 1], realm: realm, objectType: tc.companyType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p8_\(tc.name)"))
            
            let exp = expectation(description: "synced")
            var objectRecord: CKRecord?
            
            fullySync(adapter: adapter) { (uploaded, _, _) in
                objectRecord = uploaded.first
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            objectRecord!["name"] = nil
            
            let exp2 = expectation(description: "merged changes")
            
            adapter.prepareToImport()
            adapter.saveChanges(in: [objectRecord!])
            adapter.persistImportedChanges { (_) in
                exp2.fulfill()
            }
            adapter.didFinishImport(with: nil)
            
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertNil(company.value(forKey:"name"))
        }
    }
    
    func testSaveChangesInRecord_missingRelationshipProperty_setsPropertyToNil() {
        
        TestCase.defaultCases.forEach { tc in
            let companyId = tc.companyIdentifier
            let realm = realmWith(identifier: "t9_\(tc.name)", keyType: tc.keyType)
            let company = insertObject(values: ["identifier": companyId, "name": "company1", "sortIndex": 1], realm: realm, objectType: tc.companyType)
            let employee = insertObject(values: ["identifier": tc.employeeIdentifier, "name": "employee", "company": company], realm: realm, objectType: tc.employeeType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p9_\(tc.name)"))
            
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
            
            adapter.prepareToImport()
            adapter.saveChanges(in: [objectRecord!])
            adapter.persistImportedChanges { (_) in
                exp2.fulfill()
            }
            adapter.didFinishImport(with: nil)
            
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertNil(employee.value(forKey:"company"))
        }
    }
    
    func testSaveChangesInRecord_missingToManyRelationshipProperty_doesNothing() {
        
        TestCase.defaultCases.forEach { tc in
            let companyId = tc.companyIdentifier
            let realm = realmWith(identifier: "t10_\(tc.name)", keyType: tc.keyType)
            let company = insertObject(values: ["identifier": companyId, "name": "company1", "sortIndex": 1], realm: realm, objectType: tc.companyType)
            insertObject(values: ["identifier": tc.employeeIdentifier, "name": "employee", "company": company], realm: realm, objectType: tc.employeeType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p10_\(tc.name)"))
            
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
            
            adapter.prepareToImport()
            adapter.saveChanges(in: [companyRecord!])
            adapter.persistImportedChanges { (_) in
                exp2.fulfill()
            }
            adapter.didFinishImport(with: nil)
            
            waitForExpectations(timeout: 1, handler: nil)
            let employeeCount: UInt
            switch tc.keyType {
            case .int:
                employeeCount = (company as! QSCompany_Int).employees.count
            case .objectId:
                employeeCount = (company as! QSCompany_ObjId).employees.count
            case .string: fallthrough
            default:
                employeeCount = (company as! QSCompany).employees.count
            }
            
            XCTAssertEqual(employeeCount, 1)
        }
    }
    
    func testSaveChangesInRecords_ignoresPrimaryKeyField() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "11", insertEmployee: false)
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
            
            adapter.prepareToImport()
            adapter.saveChanges(in: [objectRecord!])
            adapter.persistImportedChanges { (_) in
                exp2.fulfill()
            }
            adapter.didFinishImport(with: nil)
            
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(company!.value(forKey: "name") as? String, "name 2")
            XCTAssertEqual((company!.value(forKey: "identifier") as! CustomStringConvertible).description, (tc.companyIdentifier as! CustomStringConvertible).description)
        }
    }
    
    // MARK: -
    
    func testSync_multipleRLMObjects_preservesRelationships() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, _, _) = defaultTestObjects(testCase: tc, name: "12", insertCompany: false, insertEmployee: false)
            
            let companyId = (tc.companyIdentifier as! CustomStringConvertible).description
            let companyRecord = CKRecord(recordType: String(describing: tc.companyType),
                                         recordID: CKRecord.ID(recordName: "\(String(describing: tc.companyType)).\(companyId)"))
            companyRecord["name"] = "new company" as NSString
            companyRecord["identifier"] = tc.companyIdentifier as? CKRecordValue
            companyRecord["sortIndex"] = NSNumber(value: 1)
            
            let employeeId = (tc.employeeIdentifier as! CustomStringConvertible).description
            let employeeRecord = CKRecord(recordType: String(describing: tc.employeeType),
                                          recordID: CKRecord.ID(recordName: "\(String(describing: tc.employeeType)).\(employeeId)"))
            employeeRecord["name"] = "new employee" as NSString
            employeeRecord["identifier"] = tc.employeeIdentifier as? CKRecordValue
            employeeRecord["sortIndex"] = NSNumber(value: 1)
            employeeRecord["company"] = CKRecord.Reference(recordID: companyRecord.recordID, action: .none)
            
            let exp = expectation(description: "merged changes")
            
            adapter.prepareToImport()
            adapter.saveChanges(in: [employeeRecord, companyRecord])
            adapter.persistImportedChanges { (_) in
                exp.fulfill()
            }
            adapter.didFinishImport(with: nil)
            
            waitForExpectations(timeout: 1, handler: nil)
            
            let objects = tc.companyType.allObjects(in: realm)
            XCTAssertTrue(objects.count == 1)
            
            switch tc.keyType {
            case .string:
                let company = objects.firstObject()! as! QSCompany
                XCTAssertEqual(company.value(forKey: "name") as? String, "new company")
                XCTAssertTrue(company.employees.count == 1)
                let employee = company.employees.firstObject()
                XCTAssertEqual(employee?.name, "new employee")
            case .int:
                let company = objects.firstObject()! as! QSCompany_Int
                XCTAssertEqual(company.value(forKey: "name") as? String, "new company")
                XCTAssertTrue(company.employees.count == 1)
                let employee = company.employees.firstObject()
                XCTAssertEqual(employee?.name, "new employee")
            case .objectId:
                let company = objects.firstObject()! as! QSCompany_ObjId
                XCTAssertEqual(company.value(forKey: "name") as? String, "new company")
                XCTAssertTrue(company.employees.count == 1)
                let employee = company.employees.firstObject()
                XCTAssertEqual(employee?.name, "new employee")
            default: break
            }
        }
    }
    
    func testRecordsToUpload_changedRLMObject_changesIncludeOnlyChangedProperties() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "13", insertEmployee: false)
         
            let exp = expectation(description: "synced")
            fullySync(adapter: adapter) { (_, _, _) in
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            realm.beginWriteTransaction()
            company?.setValue("name 2", forKey: "name")
            try! realm.commitWriteTransaction()
            
            waitForHasChangesNotification(from: adapter)
            
            adapter.prepareToImport()
            let records = adapter.recordsToUpload(limit: 10)
            adapter.didFinishImport(with: nil)
            
            XCTAssertTrue(records.count > 0);
            let record = records.first!;
            XCTAssertTrue(record["name"] as! String == "name 2")
            XCTAssertNil(record["sortIndex"])
        }
    }
    
    func testHasRecordID_missingRLMObject_returnsNO() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, _, _) = defaultTestObjects(testCase: tc, name: "14", insertEmployee: false)
            let exp = expectation(description: "synced")
            fullySync(adapter: adapter) { (uploaded, _, _) in
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertFalse(adapter.hasRecordID(CKRecord.ID(recordName: "missing")))
        }
    }
    
    func testHasRecordID_existingRLMObject_returnsYES() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, _, _) = defaultTestObjects(testCase: tc, name: "15", insertEmployee: false)
            
            let exp = expectation(description: "synced")
            var objectRecord: CKRecord?
            fullySync(adapter: adapter) { (uploaded, _, _) in
                objectRecord = uploaded.first!
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertTrue(adapter.hasRecordID(objectRecord!.recordID))
        }
    }
    
    func testHasChanges_noChanges_returnsNO() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, _, _) = defaultTestObjects(testCase: tc, name: "16", insertEmployee: false)
            let exp = expectation(description: "synced")
            
            fullySync(adapter: adapter) { (_, _, _) in
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertFalse(adapter.hasChanges)
        }
    }
    
    func testHasChanges_objectChanged_returnsYES() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "17", insertEmployee: false)
            
            let exp = expectation(description: "synced")
            
            fullySync(adapter: adapter) { (_, _, _) in
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertFalse(adapter.hasChanges)
            
            realm.beginWriteTransaction()
            company!.setValue("name 2", forKey: "name")
            try! realm.commitWriteTransaction()
            waitForHasChangesNotification(from: adapter)
            
            XCTAssertTrue(adapter.hasChanges)
        }
    }
    
    func testHasChanges_afterSuccessfulSync_returnsNO() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "18", insertEmployee: false)
            
            syncAdapterAndWait(adapter)
            
            XCTAssertFalse(adapter.hasChanges)
            
            realm.beginWriteTransaction()
            company!.setValue("name 2", forKey: "name")
            try! realm.commitWriteTransaction()
            
            waitForHasChangesNotification(from: adapter)
            
            XCTAssertTrue(adapter.hasChanges)
            
            let exp2 = expectation(description: "synced")
            
            fullySync(adapter: adapter) { (_, _, _) in
                exp2.fulfill()
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertFalse(adapter.hasChanges)
        }
    }
    
    func testInit_insertedRLMObject_objectIsTracked() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, _, _) = defaultTestObjects(testCase: tc, name: "19", insertCompany: false, insertEmployee: false)
            syncAdapterAndWait(adapter)
            
            let company = insertObject(values: ["name": "name", "identifier": tc.companyIdentifier, "sortIndex": 1],
                                       realm: realm,
                                       objectType: tc.companyType)
            
            waitForHasChangesNotification(from: adapter)
            syncAdapterAndWait(adapter)
            
            realm.beginWriteTransaction()
            company.setValue("name 2", forKey: "name")
            try! realm.commitWriteTransaction()
            
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
    }
    
    func testRecordsToUpload_partialUploadSuccess_stillReturnsPendingRecords() {
        
        TestCase.defaultCases.forEach { tc in
            let realm = realmWith(identifier: "t20_\(tc.name)", keyType: tc.keyType)
            insertObject(values: ["identifier": tc.companyIdentifier, "name": "company1", "sortIndex": 1], realm: realm, objectType: tc.companyType)
            insertObject(values: ["identifier": tc.companyIdentifier2, "name": "company2", "sortIndex": 2], realm: realm, objectType: tc.companyType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p20_\(tc.name)"))
            
            let exp = expectation(description: "synced")
            
            adapter.prepareToImport()
            let recordsToUpload = adapter.recordsToUpload(limit: 100)
            adapter.didUpload(savedRecords: [recordsToUpload.first!])
            adapter.persistImportedChanges { (_) in
                adapter.didFinishImport(with: nil)
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            let recordsToUploadAfterSync = adapter.recordsToUpload(limit: 100)
            
            XCTAssertTrue(recordsToUpload.count == 2)
            XCTAssertTrue(recordsToUploadAfterSync.count == 1)
        }
    }
    
    func testRecordsToUpload_doesNotIncludeRLMObjectsWithOnlyToManyRelationshipChanges() {
        
        TestCase.defaultCases.forEach { tc in
            let realm = realmWith(identifier: "t21_\(tc.name)", keyType: tc.keyType)
            let company = insertObject(values: ["identifier": tc.companyIdentifier, "name": "company1", "sortIndex": 1], realm: realm, objectType: tc.companyType)
            let employee1 = insertObject(values: ["identifier": tc.employeeIdentifier, "name": "employee1", "sortIndex": NSNumber(value: 1)], realm: realm, objectType: tc.employeeType)
            let employee2 = insertObject(values: ["identifier": tc.employeeIdentifier2, "name": "employee2", "sortIndex": NSNumber(value: 2)], realm: realm, objectType: tc.employeeType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p21_\(tc.name)"))
            
            syncAdapterAndWait(adapter)
            
            realm.beginWriteTransaction()
            employee1.setValue(company, forKey: "company")
            employee2.setValue(company, forKey: "company")
            try! realm.commitWriteTransaction()
            
            waitForHasChangesNotification(from: adapter)
            
            adapter.prepareToImport()
            let records = adapter.recordsToUpload(limit: 10)
            adapter.didFinishImport(with: nil)
            
            var companyRecord: CKRecord?
            let employeeRecords = NSMutableSet()
            for record in records {
                if record.recordType == String(describing: tc.companyType) {
                    companyRecord = record
                } else if record.recordType ==  String(describing: tc.employeeType) {
                    employeeRecords.add(record)
                }
            }
            
            XCTAssertTrue(records.count == 2)
            XCTAssertTrue(employeeRecords.count == 2)
            XCTAssertNil(companyRecord)
        }
    }
    
    func testRecordsToUpload_whenRecordWasDownloadedForRLMObject_usesCorrectRecordVersion() {
        
        let realm = realmWith(identifier: "t22")
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p22"))
        
        let data = try! Data(contentsOf: Bundle(for: SyncKitRealmTests.self).url(forResource: "QSCompany.1739C6A5-C07E-48A5-B83E-AB07694F23DF", withExtension: "")!)
        let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
        let record = CKRecord(coder: unarchiver)
        unarchiver.finishDecoding()
        
        let recordChangeTag = record?.recordChangeTag
        
        record?["name"] = "new company" as NSString
        record?["sortIndex"] = NSNumber(value: 1)
        
        let exp = expectation(description: "merged changes")
        
        adapter.prepareToImport()
        adapter.saveChanges(in: [record!])
        adapter.persistImportedChanges { (_) in
            exp.fulfill()
            adapter.didFinishImport(with: nil)
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        realm.refresh()
        
        // Now change object so it produces a record to upload
        
        let company = QSCompany.allObjects(in: realm).firstObject() as? QSCompany
        
        realm.beginWriteTransaction()
        company?.name = "another name"
        try! realm.commitWriteTransaction()
        
        waitForHasChangesNotification(from: adapter)
        
        adapter.prepareToImport()
        let records = adapter.recordsToUpload(limit: 10)
        adapter.didFinishImport(with: nil)
        
        let uploadedRecord = records.first!
        XCTAssertEqual(uploadedRecord.recordChangeTag, recordChangeTag)
    }
    
    func testRecordsToUpload_doesNotIncludePrimaryKey() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "23", insertCompany: true, insertEmployee: false)
            
            syncAdapterAndWait(adapter)
            
            realm.beginWriteTransaction()
            company?.setValue("name 2", forKey: "name")
            try! realm.commitWriteTransaction()
            
            waitForHasChangesNotification(from: adapter)
            
            adapter.prepareToImport()
            let records = adapter.recordsToUpload(limit: 10)
            adapter.didFinishImport(with: nil)
            
            XCTAssertTrue(records.count > 0)
            XCTAssertNil(records.first!["identifier"])
        }
    }
    
    func testSaveChangesInRecord_existingUniqueRLMObject_updatesRLMObject() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "24", insertCompany: true, insertEmployee: false)
            
            var objectRecord: CKRecord?
            let exp = expectation(description: "synced")
            fullySync(adapter: adapter) { (uploaded, _, _) in
                objectRecord = uploaded.first
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            objectRecord!["name"] = "name 2" as NSString
            
            let exp2 = expectation(description: "merged changes")
            
            adapter.prepareToImport()
            adapter.saveChanges(in: [objectRecord!])
            adapter.persistImportedChanges { (_) in
                exp2.fulfill()
                adapter.didFinishImport(with: nil)
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(company?.value(forKey: "name") as? String, "name 2")
        }
    }
    
    func testRecordsToUpload_uniqueRLMObjectsWithSameID_mapsRLMObjectsToSameRecord() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "25", insertCompany: true, insertEmployee: false)
            let (realm2, adapter2, company2, _) = defaultTestObjects(testCase: tc, name: "25-2", insertCompany: true, insertEmployee: false)
            
            adapter.prepareToImport()
            let records = adapter.recordsToUpload(limit: 10)
            adapter.didFinishImport(with: nil)
            
            adapter2.prepareToImport()
            let records2 = adapter2.recordsToUpload(limit: 10)
            adapter2.didFinishImport(with: nil)
            
            XCTAssertTrue(records.count == 1)
            XCTAssertTrue(records2.count == 1)
            
            XCTAssertTrue(records.first!.recordID.recordName == records2.first!.recordID.recordName)
        }
    }
    
    func testSync_uniqueRLMObjectsWithSameID_updatesRLMObjectCorrectly() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "26", insertCompany: true, insertEmployee: false)
            let (realm2, adapter2, company2, _) = defaultTestObjects(testCase: tc, name: "26-2", insertCompany: true, insertEmployee: false)
            
            let exp = expectation(description: "synced")
            
            fullySync(adapter: adapter) { (uploaded, deleted, _) in
                
                self.fullySync(adapter: adapter2, downloaded: uploaded, deleted: deleted, completion: { (_, _, _) in
                    
                    exp.fulfill()
                })
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(company2?.value(forKey: "name") as? String, "company1")
        }
    }
    
    func testSync_serverMergePolicy_prioritizesDownloadedChanges() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "27", insertCompany: true, insertEmployee: false)
            let (realm2, adapter2, company2, _) = defaultTestObjects(testCase: tc, name: "27-2", insertCompany: true, insertEmployee: false)
            
            adapter2.mergePolicy = .server
            
            let exp = expectation(description: "synced")
            
            fullySync(adapter: adapter) { (uploaded, _, _) in
                
                self.fullySync(adapter: adapter2, downloaded: uploaded, deleted: [], completion: { (_, _, _) in
                    exp.fulfill()
                })
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(company2?.value(forKey: "name") as? String, "company1")
        }
    }
    
    func testSync_clientMergePolicy_prioritizesLocalChanges() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "28", insertCompany: true, insertEmployee: false)
            let realm2 = realmWith(identifier: "t28-2_\(tc.name)", keyType: tc.keyType)
            let company2 = insertObject(values: ["identifier": company!.value(forKey: "identifier")!, "name": "company2"], realm: realm2, objectType: tc.companyType)
            let adapter2 = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p28-2_\(tc.name)"))
            adapter2.mergePolicy = .client
            
            let exp = expectation(description: "synced")
            
            fullySync(adapter: adapter) { (uploaded, _, _) in
                
                self.fullySync(adapter: adapter2, downloaded: uploaded, deleted: [], completion: { (_, _, _) in
                    exp.fulfill()
                })
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(company2.value(forKey: "name") as? String, "company2")
        }
    }
    
    func testSync_customMergePolicy_callsDelegateForResolution() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "29", insertCompany: true, insertEmployee: false)
            let realm2 = realmWith(identifier: "t29-2_\(tc.name)", keyType: tc.keyType)
            let company2 = insertObject(values: ["identifier": company!.value(forKey: "identifier")!, "name": "company2", "sortIndex": 2], realm: realm2, objectType: tc.companyType)
            let adapter2 = realmAdapter(targetConfiguration: realm2.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p29-2_\(tc.name)"))
            adapter2.mergePolicy = .custom
            adapter2.delegate = self
            
            let exp = expectation(description: "synced")
            
            var calledCustomMergePolicyMethod = false
            customMergePolicyBlock = { (adapter, changes, object) in
                if adapter == adapter2 && changes["name"] as! String == "company1" {
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
            XCTAssertEqual(company2.value(forKey: "name") as? String, "company3")
        }
    }
    
    // MARK:- Asset
    
    
    func testRecordToUpload_dataProperty_uploadedAsAsset() {
        
        TestCase.defaultCases.forEach { tc in
            let realm = realmWith(identifier: "t40_\(tc.name)", keyType: tc.keyType)
            let _ = insertObject(values: ["identifier": tc.employeeIdentifier, "name": "employee1", "photo": NSData()], realm: realm, objectType: tc.employeeType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p40_\(tc.name)"))
            
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
    }
    
    func testRecordToUpload_dataProperty_forceDataType_uploadedAsData() {
        
        TestCase.defaultCases.forEach { tc in
            let realm = realmWith(identifier: "t41_\(tc.name)", keyType: tc.keyType)
            let _ = insertObject(values: ["identifier": tc.employeeIdentifier, "name": "employee1", "photo": NSData()], realm: realm, objectType: tc.employeeType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p41_\(tc.name)"))
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
    }
    
    func testRecordToUpload_dataPropertyNil_nilsProperty() {
        
        TestCase.defaultCases.forEach { tc in
            let realm = realmWith(identifier: "t42_\(tc.name)", keyType: tc.keyType)
            let employee = insertObject(values: ["identifier": tc.employeeIdentifier, "name": "employee1", "photo": NSData()], realm: realm, objectType: tc.employeeType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p42_\(tc.name)"))
            
            let exp = expectation(description: "synced")
            
            fullySync(adapter: adapter) { (uploaded, _, _) in
                
                exp.fulfill()
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            realm.beginWriteTransaction()
            employee.setValue(nil, forKey: "photo")
            try? realm.commitWriteTransaction()
            
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
    }
    
    func testSaveChangesInRecord_assetProperty_updatesData() {
        
        TestCase.defaultCases.forEach { tc in
            let realm = realmWith(identifier: "t43_\(tc.name)", keyType: tc.keyType)
            let employee = insertObject(values: ["identifier": tc.employeeIdentifier, "name": "employee1"], realm: realm, objectType: tc.employeeType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p43_\(tc.name)"))
            
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
            
            XCTAssertNotNil(employee.value(forKey:"photo"));
            XCTAssertEqual((employee.value(forKey: "photo") as? Data)?.count, 8);
        }
    }
    
    func testSaveChangesInRecord_assetPropertyNil_nilsData() {
        
        TestCase.defaultCases.forEach { tc in
            let realm = realmWith(identifier: "t44_\(tc.name)", keyType: tc.keyType)
            let employee = insertObject(values: ["identifier": tc.employeeIdentifier, "name": "employee1", "photo": NSData()], realm: realm, objectType: tc.employeeType)
            let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p44_\(tc.name)"))
            
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
            
            XCTAssertNil(employee.value(forKey:"photo"))
        }
    }
    
    // MARK: - Sharing
    
    func testRecordForRLMObjectWithIdentifier_existingRLMObject_returnsRecord() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "50")
            let record = adapter.record(for: company!)
            XCTAssertNotNil(record)
            XCTAssertTrue(record!.recordID.recordName.hasPrefix("QSCompany"))
        }
    }
    
    func testShareForRLMObjectWithIdentifier_noShare_returnsNil() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "51")
            let share = adapter.share(for: company!)
            XCTAssertNil(share)
        }
    }

    func testShareForRLMObjectWithIdentifier_saveShareCalled_returnsShare() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "52")
            let record = adapter.record(for: company!)
            let share = CKShare(rootRecord: record!)
            
            adapter.save(share: share, for: company!)
            adapter.save(share: share, for: company!)
            
            let share2 = adapter.share(for: company!)
            XCTAssertNotNil(share2)
        }
    }

    func testShareForRLMObjectWithIdentifier_shareDeleted_returnsNil() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "53")
            
            let record = adapter.record(for: company!)
            let share = CKShare(rootRecord: record!)
            
            adapter.save(share: share, for: company!)
            
            XCTAssertNotNil(adapter.share(for: company!))
            
            adapter.deleteShare(for: company!)
            
            XCTAssertNil(adapter.share(for: company!))
        }
    }

    func testSaveChangesInRecords_includesShare_savesRLMObjectAndShare() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, _, _) = defaultTestObjects(testCase: tc, name: "54", insertCompany: false, insertEmployee: false)
            let companyRecord = CKRecord(recordType: String(describing: tc.companyType), recordID: CKRecord.ID(recordName: "\(String(describing: tc.companyType)).\((tc.companyIdentifier as! CustomStringConvertible).description)"))
            companyRecord["name"] = "new company" as NSString
            companyRecord["sortIndex"] = 0
            
            let shareRecord = CKShare(rootRecord: companyRecord, shareID: CKRecord.ID(recordName: "QSShare.forCompany"))
            
            let expectation = self.expectation(description: "synced")
            fullySync(adapter: adapter, downloaded: [companyRecord, shareRecord], deleted: []) { (_, _, _) in
                expectation.fulfill()
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            
            let company = tc.companyType.allObjects(in: realm).firstObject()
            let share = adapter.share(for: company!)
            
            XCTAssertNotNil(company)
            XCTAssertNotNil(share)
            XCTAssertEqual(company?.value(forKey: "name") as? String, "new company")
            XCTAssertTrue(share?.recordID.recordName == "QSShare.forCompany")
        }
    }

    func testDeleteRecordsWithIDs_containsShare_deletesShare() {
        
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, _) = defaultTestObjects(testCase: tc, name: "55")
            
            let record = adapter.record(for: company!)
            let shareID = CKRecord.ID(recordName: "CKShare.identifier", zoneID: record!.recordID.zoneID)
            let share = CKShare(rootRecord: record!, shareID: shareID)
            
            adapter.save(share: share, for: company!)
            
            let savedShare = adapter.share(for: company!)
            XCTAssertNotNil(savedShare)
            
            let expectation = self.expectation(description: "synced")
            fullySync(adapter: adapter, downloaded: [], deleted: [shareID]) { (_, _, _) in
                expectation.fulfill()
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            
            let updatedShare = adapter.share(for: company!)
            XCTAssertNil(updatedShare)
        }
    }
    
    func testRecordsToUpload_includesAnyParentRecordsInBatch() {
        TestCase.defaultCases.forEach { tc in
            let (realm, adapter, company, employee) = defaultTestObjects(testCase: tc, name: "56")
            
            adapter.prepareToImport()
            let records = adapter.recordsToUpload(limit: 1)
            adapter.didFinishImport(with: nil)
            
            XCTAssertEqual(records.count, 2);
            let companyRecord = records.first { $0.recordID.recordName.contains("Company") }
            let employeeRecord = records.first { $0.recordID.recordName.contains("Employee") }
            XCTAssertNotNil(companyRecord)
            XCTAssertNotNil(employeeRecord)
        }
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

        let records =  adapter.recordsToUpdateParentRelationshipsForRoot(company)
        XCTAssertEqual(records.count, 3)
        for record in records {
            XCTAssertTrue(record.recordID.recordName.contains("com1") ||
                record.recordID.recordName.contains("emp1") ||
                record.recordID.recordName.contains("emp2"))
        }
    }
    
    @available(iOS 15, OSX 12, *)
    func testShareForRecordZone_noShare_returnsNil() {
        let cases = TestCase.defaultCases
        cases.forEach { tc in
            let (_, adapter, _, _) = defaultTestObjects(testCase: tc, name: "61")
            let share = adapter.shareForRecordZone()
            XCTAssertNil(share)
        }
    }
    
    @available(iOS 15, OSX 12, *)
    func testShareForRecordZone_saveShareCalled_returnsShare() {
        
        let cases = TestCase.defaultCases
        cases.forEach { tc in
            let (_, adapter, _, _) = defaultTestObjects(testCase: tc, name: "62")
            
            let share = CKShare(recordZoneID: adapter.recordZoneID)
            
            adapter.saveShareForRecordZone(share: share)
            
            let share2 = adapter.shareForRecordZone()
            XCTAssertNotNil(share2)
        }
    }
    
    @available(iOS 15, OSX 12, *)
    func testShareForRecordZone_shareDeleted_returnsNil() {
        
        let cases = TestCase.defaultCases
        cases.forEach { tc in
            let (_, adapter, _, _) = defaultTestObjects(testCase: tc, name: "63")
            
            
            let share = CKShare(recordZoneID: adapter.recordZoneID)
            
            adapter.saveShareForRecordZone(share: share)
            
            XCTAssertNotNil(adapter.shareForRecordZone())
            
            adapter.deleteShareForRecordZone()
            
            XCTAssertNil(adapter.shareForRecordZone())
        }
    }
    
    @available(iOS 15, OSX 12, *)
    func testSaveChangesInRecords_includesShareForRecordZone_savesShare() {
        
        let cases = TestCase.defaultCases
        cases.forEach { tc in
            let (_, adapter, _, _) = defaultTestObjects(testCase: tc, name: "64", insertCompany: false, insertEmployee: false)

            let shareRecord = CKShare(recordZoneID: adapter.recordZoneID)
            
            let expectation = self.expectation(description: "synced")
            fullySync(adapter: adapter, downloaded: [shareRecord], deleted: []) { (_, _, _) in
                expectation.fulfill()
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            
            let share = adapter.shareForRecordZone()
            
            XCTAssertNotNil(share)
            XCTAssertTrue(share?.recordID.recordName == CKRecordNameZoneWideShare)
        }
    }
    
    @available(iOS 15, OSX 12, *)
    func testDeleteRecordsWithIDs_containsShareForRecordZone_deletesShare() {
        let cases = TestCase.defaultCases
        cases.forEach { tc in
            let (_, adapter, _, _) = defaultTestObjects(testCase: tc, name: "65")
            
            let share = CKShare(recordZoneID: adapter.recordZoneID)
            
            adapter.saveShareForRecordZone(share: share)
            
            let savedShare = adapter.shareForRecordZone()
            XCTAssertNotNil(savedShare)
            
            let expectation = self.expectation(description: "synced")
            fullySync(adapter: adapter, downloaded: [], deleted: [share.recordID]) { (_, _, _) in
                expectation.fulfill()
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            
            let updatedShare = adapter.shareForRecordZone()
            XCTAssertNil(updatedShare)
        }
    }

    
    // MARK: - 0.6.0
    
    func testOldToken_preserved() {
        
        let realm = realmWith(identifier: "t70")
        
        // Delete any leftover data
        let synchronizer = CloudKitSynchronizer.privateSynchronizer(containerName: "container", configuration: realm.configuration)
        let adapter = synchronizer.modelAdapters.first as? RealmAdapter
        
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
        
        let data = try! Data(contentsOf: Bundle(for: SyncKitRealmTests.self).url(forResource: "serverChangeToken.AQAAAWPa1DUC", withExtension: nil)!)
        let token = NSKeyedUnarchiver.unarchiveObject(with: data) as! CKServerChangeToken
        UserDefaults.standard.set(data, forKey: "containerQSCloudKitFetchChangesServerTokenKey")
        
        let synchronizer2 = CloudKitSynchronizer.privateSynchronizer(containerName: "container", configuration: realm.configuration)
        let adapterToken = synchronizer2.modelAdapters.first?.serverChangeToken
        
        XCTAssertNotNil(token);
        XCTAssertTrue(adapterToken == token);
        XCTAssertNil(UserDefaults.standard.object(forKey: "containerQSCloudKitFetchChangesServerTokenKey"))
    }
    
    // MARK: - Custom record processing
    
    func testRecordProcessingDelegateCalledOnUpload() {
        let realm = realmWith(identifier: "t80")
        let _ = insertCompany(values: ["identifier": "1", "name": "company1", "sortIndex": 1], realm: realm)
        
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p80"))
        let delegate = RecordProcessingDelegate()
        delegate.shouldProcessUploadClosure = { property, object, record in
            if property == "name",
               let object = object as? QSCompany,
               let name = object.name,
               let range = name.range(of: "company") {
                record[property] = String(name[range.upperBound...])
                return false
            } else {
                return true
            }
        }
        adapter.recordProcessingDelegate = delegate
        
        let exp = expectation(description: "synced")
        var record: CKRecord?
        fullySync(adapter: adapter) { (uploaded, deleted, error) in
            record = uploaded.first
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(record?["name"], "1")
    }
    
    func testRecordProcessingDelegateCalledOnDownload() {
        let realm = realmWith(identifier: "t81")
        
        let adapter = realmAdapter(targetConfiguration: realm.configuration, persistenceConfiguration: persistenceConfigurationWith(identifier: "p81"))
        let delegate = RecordProcessingDelegate()
        delegate.shouldProcessDownloadClosure = { property, object, record in
            if property == "name",
               let object = object as? QSCompany {
                object.name = "company" + (record["name"] ?? "")
                return false
            } else {
                return true
            }
        }
        adapter.recordProcessingDelegate = delegate
        
        let objectRecord = CKRecord(recordType: "QSCompany", recordID: CKRecord.ID(recordName: "QSCompany.1"))
        objectRecord["name"] = "1" as NSString
        objectRecord["identifier"] = "1" as NSString
        objectRecord["sortIndex"] = NSNumber(value: 1)
        
        let exp = expectation(description: "synced")
        fullySync(adapter: adapter, downloaded: [objectRecord], deleted: []) { (uploaded, deleted, error) in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        let companies = QSCompany.allObjects(in: realm)
        
        XCTAssertEqual(companies.firstObject()?.name, "company1")
    }
    
}

@available(iOS 15, OSX 12, *)
extension SyncKitRealmTests {
    func testRecordsToUpload_encryptedFields_areEncryptedInRecord() {
        let configuration = RLMRealmConfiguration()
        configuration.inMemoryIdentifier = "t100"
        configuration.objectClasses = [EntityWithEncryptedFields.self]
        let realm = try! RLMRealm(configuration: configuration)
        
        insertObject(values: ["identifier": "1", "name": "company1", "secret": "mySecret"],
                     realm: realm,
                     objectType: EntityWithEncryptedFields.self)
        
        let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                   persistenceConfiguration: persistenceConfigurationWith(identifier: "p100"))
        
        adapter.prepareToImport()
        let records = adapter.recordsToUpload(limit: 10)
        adapter.didFinishImport(with: nil)
        
        XCTAssertTrue(records.count > 0)
        if let record = records.first {
            XCTAssertEqual(record["name"] as? String, "company1")
            XCTAssertNil(record["secret"])
            XCTAssertEqual(record.encryptedValues["secret"], "mySecret")
        }
    }
    
    func testSaveChangesInRecord_encryptedFields_changesAreSaved() {
        let configuration = RLMRealmConfiguration()
        configuration.inMemoryIdentifier = "t101"
        configuration.objectClasses = [EntityWithEncryptedFields.self]
        let realm = try! RLMRealm(configuration: configuration)
        
        let adapter = realmAdapter(targetConfiguration: realm.configuration,
                                   persistenceConfiguration: persistenceConfigurationWith(identifier: "p101"))
        
        let record = CKRecord(recordType: "EntityWithEncryptedFields", recordID: CKRecord.ID(recordName: "EntityWithEncryptedFields.myID", zoneID: adapter.recordZoneID))
        record["name"] = "name"
        record.encryptedValues["secret"] = "mySecret"
        
        waitUntilSynced(adapter: adapter, downloaded: [record], deleted: [])
        
        let object = EntityWithEncryptedFields.allObjects(in: realm).firstObject()
        XCTAssertNotNil(object)
        if let object = object {
            XCTAssertEqual(object.name, "name")
            XCTAssertEqual(object.identifier, "myID")
            XCTAssertEqual(object.secret, "mySecret")
        }
    }
}
