//
//  QSTestEntity+CoreDataProperties.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 18/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData


extension QSTestEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSTestEntity> {
        return NSFetchRequest<QSTestEntity>(entityName: "QSTestEntity")
    }

    @NSManaged public var identifier: String?
    @NSManaged public var names: NSArray?

}
