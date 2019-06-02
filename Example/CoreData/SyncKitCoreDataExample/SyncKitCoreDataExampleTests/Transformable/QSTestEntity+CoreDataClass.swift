//
//  QSTestEntity+CoreDataClass.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 18/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData
import SyncKit

@objc(QSTestEntity)
public class QSTestEntity: NSManagedObject, PrimaryKey {
    public static func primaryKey() -> String {
        return "identifier"
    }
}
