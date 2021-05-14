//
//  QSCompany_UUID+CoreDataProperties.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 12/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData


extension QSCompany_UUID {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSCompany_UUID> {
        return NSFetchRequest<QSCompany_UUID>(entityName: "QSCompany_UUID")
    }

    @NSManaged public var identifier: UUID?
    @NSManaged public var name: String?
    @NSManaged public var sortIndex: NSNumber?
    @NSManaged public var employees: NSSet?

}

// MARK: Generated accessors for employees
extension QSCompany_UUID {

    @objc(addEmployeesObject:)
    @NSManaged public func addToEmployees(_ value: QSEmployee_UUID)

    @objc(removeEmployeesObject:)
    @NSManaged public func removeFromEmployees(_ value: QSEmployee_UUID)

    @objc(addEmployees:)
    @NSManaged public func addToEmployees(_ values: NSSet)

    @objc(removeEmployees:)
    @NSManaged public func removeFromEmployees(_ values: NSSet)

}
