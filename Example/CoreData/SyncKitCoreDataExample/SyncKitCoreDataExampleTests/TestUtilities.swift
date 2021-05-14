//
//  TestUtilities.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 14/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import XCTest
import CloudKit
import CoreData

extension CKServerChangeToken {
    static func stub() -> CKServerChangeToken {
        let fileURL = Bundle(for: MockModelAdapter.self).url(forResource: "serverChangeToken.AQAAAWPa1DUC", withExtension: "")!
        let data = NSData(contentsOf: fileURL)!
        return NSKeyedUnarchiver.unarchiveObject(with: data as Data) as! CKServerChangeToken
    }
}

extension QSCompany {
    static func stubbedRecord() -> CKRecord {
        let fileURL = Bundle(for: MockModelAdapter.self).url(forResource: "QSCompany.1739C6A5-C07E-48A5-B83E-AB07694F23DF", withExtension: "")!
        let data = NSData(contentsOf: fileURL)!
        let unarchiver = try! NSKeyedUnarchiver(forReadingFrom: data as Data)
        let record = CKRecord(coder: unarchiver)
        unarchiver.finishDecoding()
        return record!
    }
}

protocol Company: NSManagedObject {
    var _identifier: Any? { get set }
    var name: String? { get set}
    var sortIndex: NSNumber? { get set }
    var employees: NSSet? { get set }
}

protocol Employee: NSManagedObject {
    var _identifier: Any? { get set }
    var name: String? { get set }
    var photo: Data? { get set }
    var sortIndex: NSNumber? { get set }
    var _company: Company? { get set }
}

extension QSCompany: Company {
    var _identifier: Any? {
        get { identifier }
        set { identifier = newValue as? String }
    }
}
extension QSCompany_Int: Company {
    var _identifier: Any? {
        get { identifier }
        set { identifier = newValue as! Int64 }
    }
}
extension QSCompany_UUID: Company {
    var _identifier: Any? {
        get { identifier }
        set { identifier = newValue as? UUID }
    }
}
extension QSEmployee: Employee {
    var _identifier: Any? {
        get { identifier }
        set { identifier = newValue as? String }
    }
    
    var _company: Company? {
        get { company }
        set { company = newValue as! QSCompany? }
    }
}
extension QSEmployee_Int: Employee {
    var _identifier: Any? {
        get { identifier }
        set { identifier = newValue as! Int64 }
    }
    var _company: Company? {
        get { company }
        set { company = newValue as! QSCompany_Int? }
    }
}
extension QSEmployee_UUID: Employee {
    var _identifier: Any? {
        get { identifier }
        set { identifier = newValue as? UUID }
    }
    var _company: Company? {
        get { company }
        set { company = newValue as! QSCompany_UUID? }
    }
}

struct TestCase {
    let keyType: NSAttributeType
    let values: [String: Any]!
    let companyIdentifier: Any
    let companyIdentifier2: Any
    let employeeIdentifier: Any
    let employeeIdentifier2: Any
    init(_ keyType: NSAttributeType,
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
    
    var companyType: NSManagedObject.Type {
        switch keyType {
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            return QSCompany_Int.self
        case .UUIDAttributeType:
            return QSCompany_UUID.self
        case .stringAttributeType: fallthrough
        default:
            return QSCompany.self
        }
    }
    
    var companyEntityType: String {
        switch keyType {
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            return "QSCompany_Int"
        case .UUIDAttributeType:
            return "QSCompany_UUID"
        case .stringAttributeType:
            return "QSCompany"
        default: return ""
        }
    }
    
    var employeeType: NSManagedObject.Type {
        switch keyType {
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            return QSEmployee_Int.self
        case .UUIDAttributeType:
            return QSEmployee_UUID.self
        case .stringAttributeType: fallthrough
        default:
            return QSEmployee.self
        }
    }
    
    var employeeEntityType: String {
        switch keyType {
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            return "QSEmployee_Int"
        case .UUIDAttributeType:
            return "QSEmployee_UUID"
        case .stringAttributeType:
            return "QSEmployee"
        default: return ""
        }
    }
    
    var companyIdentifierString: String {
        switch keyType {
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
        return String(companyIdentifier as! Int)
        case .UUIDAttributeType:
            return (companyIdentifier as! UUID).uuidString
        case .stringAttributeType:
            return companyIdentifier as! String
        default: return ""
        }
    }
    
    var employeeIdentifierString: String {
        switch keyType {
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
        return String(employeeIdentifier as! Int)
        case .UUIDAttributeType:
            return (employeeIdentifier as! UUID).uuidString
        case .stringAttributeType:
            return employeeIdentifier as! String
        default: return ""
        }
    }
    
    static var defaultCases: [TestCase] {
        return [
            TestCase(.stringAttributeType, companyIdentifier: "1", companyIdentifier2: "2", employeeIdentifier: "10", employeeIdentifier2: "11"),
            TestCase(.integer64AttributeType, companyIdentifier: 1, companyIdentifier2: 2, employeeIdentifier: 10, employeeIdentifier2: 11),
            TestCase(.UUIDAttributeType, companyIdentifier: UUID(), companyIdentifier2: UUID(), employeeIdentifier: UUID(), employeeIdentifier2: UUID())
        ]
    }
}
