//
//  QSEmployee_UUID+CoreDataClass.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 12/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData
import SyncKit

@objc(QSEmployee_UUID)
public class QSEmployee_UUID: NSManagedObject, PrimaryKey {

    public static func primaryKey() -> String {
        return "identifier"
    }
}
