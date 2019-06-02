//
//  QSCompany+CoreDataClass.swift
//  
//
//  Created by Manuel Entrena on 11/06/2019.
//
//

import Foundation
import CoreData
import SyncKit

@objc(QSCompany)
public class QSCompany: NSManagedObject, PrimaryKey {
    public static func primaryKey() -> String {
        return "identifier"
    }
}
