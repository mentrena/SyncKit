//
//  QSTestEntity2+CoreDataProperties.swift
//  
//
//  Created by Manuel Entrena on 15/09/2019.
//
//

import Foundation
import CoreData


extension QSTestEntity2 {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSTestEntity2> {
        return NSFetchRequest<QSTestEntity2>(entityName: "QSTestEntity2")
    }

    @NSManaged public var identifier: String?
    @NSManaged public var names: NSArray?

}
