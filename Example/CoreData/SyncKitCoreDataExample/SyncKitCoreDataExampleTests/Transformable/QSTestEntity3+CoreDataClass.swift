//
//  QSTestEntity3+CoreDataClass.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel on 24/06/2022.
//  Copyright © 2022 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData
import SyncKit

@objc(QSTestEntity3)
public class QSTestEntity3: NSManagedObject, PrimaryKey {
    public static func primaryKey() -> String {
        return "identifier"
    }
}
