//
//  QSEmployee_UUID+CoreDataProperties.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 12/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData


extension QSEmployee_UUID {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSEmployee_UUID> {
        return NSFetchRequest<QSEmployee_UUID>(entityName: "QSEmployee_UUID")
    }

    @NSManaged public var identifier: UUID?
    @NSManaged public var name: String?
    @NSManaged public var photo: Data?
    @NSManaged public var sortIndex: NSNumber?
    @NSManaged public var company: QSCompany_UUID?

}
