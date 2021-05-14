//
//  QSCompany_UUID+CoreDataClass.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 12/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//
//

import Foundation
import CoreData
import SyncKit

@objc(QSCompany_UUID)
public class QSCompany_UUID: NSManagedObject, PrimaryKey {

    public static func primaryKey() -> String {
        return "identifier"
    }
}
