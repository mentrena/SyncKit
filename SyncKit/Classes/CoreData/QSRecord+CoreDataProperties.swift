//
//  QSRecord+CoreDataProperties.swift
//  
//
//  Created by Manuel Entrena on 02/06/2019.
//
//

import Foundation
import CoreData


extension QSRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSRecord> {
        return NSFetchRequest<QSRecord>(entityName: "QSRecord")
    }

    @NSManaged public var encodedRecord: NSData?
    @NSManaged public var forEntity: QSSyncedEntity?

}
