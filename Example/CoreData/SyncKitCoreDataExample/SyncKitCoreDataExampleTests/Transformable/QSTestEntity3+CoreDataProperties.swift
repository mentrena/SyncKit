//
//  QSTestEntity3+CoreDataProperties.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel on 24/06/2022.
//  Copyright © 2022 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData


extension QSTestEntity3 {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSTestEntity3> {
        return NSFetchRequest<QSTestEntity3>(entityName: "QSTestEntity3")
    }

    @NSManaged public var identifier: String?
    @NSManaged public var names: NSArray?

}
