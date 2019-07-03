//
//  QSPendingRelationship+CoreDataProperties.swift
//  
//
//  Created by Manuel Entrena on 02/06/2019.
//
//

import Foundation
import CoreData


extension QSPendingRelationship {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSPendingRelationship> {
        return NSFetchRequest<QSPendingRelationship>(entityName: "QSPendingRelationship")
    }

    @NSManaged public var relationshipName: String?
    @NSManaged public var targetIdentifier: String?
    @NSManaged public var forEntity: QSSyncedEntity?

}
