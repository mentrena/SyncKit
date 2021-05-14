//
//  QSCompany_Int+CoreDataProperties.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 12/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData


extension QSCompany_Int {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSCompany_Int> {
        return NSFetchRequest<QSCompany_Int>(entityName: "QSCompany_Int")
    }

    @NSManaged public var identifier: Int64
    @NSManaged public var name: String?
    @NSManaged public var sortIndex: NSNumber?
    @NSManaged public var employees: NSSet?

}

// MARK: Generated accessors for employees
extension QSCompany_Int {

    @objc(addEmployeesObject:)
    @NSManaged public func addToEmployees(_ value: QSEmployee_Int)

    @objc(removeEmployeesObject:)
    @NSManaged public func removeFromEmployees(_ value: QSEmployee_Int)

    @objc(addEmployees:)
    @NSManaged public func addToEmployees(_ values: NSSet)

    @objc(removeEmployees:)
    @NSManaged public func removeFromEmployees(_ values: NSSet)

}
