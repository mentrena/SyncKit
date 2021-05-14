//
//  QSEmployee+CoreDataProperties.swift
//  
//
//  Created by Manuel Entrena on 11/06/2019.
//
//

import Foundation
import CoreData


extension QSEmployee {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSEmployee> {
        return NSFetchRequest<QSEmployee>(entityName: "QSEmployee")
    }

    @NSManaged public var identifier: String?
    @NSManaged public var name: String?
    @NSManaged public var photo: Data?
    @NSManaged public var sortIndex: NSNumber?
    @NSManaged public var company: QSCompany?

}
