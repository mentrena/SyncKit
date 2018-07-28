//
//  QSEmployee+CoreDataProperties.swift
//  
//
//  Created by Jérôme Haegeli on 28.07.18.
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
    @NSManaged public var photo: NSData?
    @NSManaged public var sortIndex: NSNumber?
    @NSManaged public var company: QSCompany?

}
