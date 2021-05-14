//
//  QSEmployee_Int+CoreDataProperties.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 12/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData


extension QSEmployee_Int {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSEmployee_Int> {
        return NSFetchRequest<QSEmployee_Int>(entityName: "QSEmployee_Int")
    }

    @NSManaged public var name: String?
    @NSManaged public var identifier: Int64
    @NSManaged public var photo: Data?
    @NSManaged public var sortIndex: NSNumber?
    @NSManaged public var company: QSCompany_Int?

}
