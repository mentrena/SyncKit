//
//  EntityWithEncryptedFields+CoreDataClass.swift
//  EntityWithEncryptedFields
//
//  Created by Manuel on 09/08/2021.
//
//

import Foundation
import CoreData
import SyncKit

@objc(EntityWithEncryptedFields)
public class EntityWithEncryptedFields: NSManagedObject {

}

extension EntityWithEncryptedFields: PrimaryKey {
    public static func primaryKey() -> String {
        "identifier"
    }
}

extension EntityWithEncryptedFields: EncryptedObject {
    public static func encryptedFields() -> [String] {
        ["secret"]
    }
}
