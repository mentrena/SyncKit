//
//  IntTestEntity+CoreDataProperties.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 03/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData


extension IntTestEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<IntTestEntity> {
        return NSFetchRequest<IntTestEntity>(entityName: "IntTestEntity")
    }

    @NSManaged public var identifier: Int64
    @NSManaged public var name: String?

}
