//
//  UUIDTestEntity+CoreDataClass.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 03/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData
import SyncKit

@objc(UUIDTestEntity)
public class UUIDTestEntity: NSManagedObject, PrimaryKey {
    public static func primaryKey() -> String {
        return "identifier"
    }
}
