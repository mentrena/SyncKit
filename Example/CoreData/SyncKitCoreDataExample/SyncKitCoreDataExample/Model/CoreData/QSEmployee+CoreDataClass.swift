//
//  QSEmployee+CoreDataClass.swift
//  
//
//  Created by Manuel Entrena on 11/06/2019.
//
//

import Foundation
import CoreData
import SyncKit

@objc(QSEmployee)
public class QSEmployee: NSManagedObject, PrimaryKey, ParentKey {
    public static func primaryKey() -> String {
        return "identifier"
    }
    
    public static func parentKey() -> String {
        return "company"
    }
}
