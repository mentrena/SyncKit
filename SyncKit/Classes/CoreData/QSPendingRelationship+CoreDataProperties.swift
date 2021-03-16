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

    @nonobjc class func fetchRequest() -> NSFetchRequest<QSPendingRelationship> {
        return NSFetchRequest<QSPendingRelationship>(entityName: "QSPendingRelationship")
    }

    @NSManaged var relationshipName: String?
    @NSManaged var targetIdentifier: String?
    @NSManaged var forEntity: QSSyncedEntity?

}
