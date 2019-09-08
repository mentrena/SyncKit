//
//  QSTestEntity2+CoreDataClass.swift
//  
//
//  Created by Manuel Entrena on 15/09/2019.
//
//

import Foundation
import CoreData
import SyncKit

@objc(QSTestEntity2)
public class QSTestEntity2: NSManagedObject, PrimaryKey {
    public static func primaryKey() -> String {
        return "identifier"
    }
}
