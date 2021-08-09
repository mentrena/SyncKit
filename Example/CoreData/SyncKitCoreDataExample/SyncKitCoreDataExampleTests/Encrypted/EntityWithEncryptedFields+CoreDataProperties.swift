//
//  EntityWithEncryptedFields+CoreDataProperties.swift
//  EntityWithEncryptedFields
//
//  Created by Manuel on 09/08/2021.
//
//

import Foundation
import CoreData


extension EntityWithEncryptedFields {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<EntityWithEncryptedFields> {
        return NSFetchRequest<EntityWithEncryptedFields>(entityName: "EntityWithEncryptedFields")
    }

    @NSManaged public var identifier: String?
    @NSManaged public var name: String?
    @NSManaged public var secret: String?

}
