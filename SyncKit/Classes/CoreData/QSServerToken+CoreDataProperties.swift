//
//  QSServerToken+CoreDataProperties.swift
//  
//
//  Created by Manuel Entrena on 02/06/2019.
//
//

import Foundation
import CoreData


extension QSServerToken {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSServerToken> {
        return NSFetchRequest<QSServerToken>(entityName: "QSServerToken")
    }

    @NSManaged public var token: NSData?

}
