//
//  PrimaryKey.swift
//  Pods-CoreDataExample
//
//  Created by Manuel Entrena on 25/04/2019.
//

import Foundation

/**
 *   The name of the property that acts as primary key for objects of this class. Primary key values are expected to remain the same
 *  for the lifetime of the object, and they are expected to be unique.
 *  Valid types are String, Int and UUID for Core Data, and String, Int and ObjectId for Realm.
 */
@objc public protocol PrimaryKey: AnyObject {
    
    /// Name of the primary key property.
    static func primaryKey() -> String
}

/**
 *  The name of the property that references this object's parent, if there's one. Used to create a hierarchy
 *  of objects for CloudKit sharing.
 */
@objc public protocol ParentKey: AnyObject {
    
    /// Name of the parent key property.
    static func parentKey() -> String
}

/**
 *  Can be adopted by classes to use CloudKit encryption for some fields
 */
@available(iOS 15, OSX 12, watchOS 8.0, *)
@objc public protocol EncryptedObject: AnyObject {
    
    /// Name of the fields that should use encryption
    static func encryptedFields() -> [String]
}
