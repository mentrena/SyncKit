//
//  QSCompany+CoreDataProperties.swift
//  
//
//  Created by Manuel Entrena on 11/06/2019.
//
//

import Foundation
import CoreData


extension QSCompany {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSCompany> {
        return NSFetchRequest<QSCompany>(entityName: "QSCompany")
    }

    @NSManaged public var identifier: String?
    @NSManaged public var name: String?
    @NSManaged public var sortIndex: NSNumber?
    @NSManaged public var employees: NSSet?

}

// MARK: Generated accessors for employees
extension QSCompany {

    @objc(addEmployeesObject:)
    @NSManaged public func addToEmployees(_ value: QSEmployee)

    @objc(removeEmployeesObject:)
    @NSManaged public func removeFromEmployees(_ value: QSEmployee)

    @objc(addEmployees:)
    @NSManaged public func addToEmployees(_ values: NSSet)

    @objc(removeEmployees:)
    @NSManaged public func removeFromEmployees(_ values: NSSet)

}
