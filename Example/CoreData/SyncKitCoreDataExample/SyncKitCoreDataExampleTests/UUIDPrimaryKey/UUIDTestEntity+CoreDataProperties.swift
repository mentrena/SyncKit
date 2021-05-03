//
//  UUIDTestEntity+CoreDataProperties.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 03/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData


extension UUIDTestEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UUIDTestEntity> {
        return NSFetchRequest<UUIDTestEntity>(entityName: "UUIDTestEntity")
    }

    @NSManaged public var name: String?
    @NSManaged public var identifier: UUID?

}
