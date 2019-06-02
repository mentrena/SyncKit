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
 */
@objc public protocol PrimaryKey: class {
    
    static func primaryKey() -> String
}

/**
 *  The name of the property that references this object's parent, if there's one. Used to create a hierarchy
 *  of objects for CloudKit sharing.
 */
@objc public protocol ParentKey: class {
    
    static func parentKey() -> String
}
