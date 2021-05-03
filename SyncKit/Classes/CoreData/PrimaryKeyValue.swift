//
//  PrimaryKeyValue.swift
//  Pods
//
//  Created by Manuel Entrena on 03/05/2021.
//

import Foundation
import CoreData

enum PrimaryKeyValue: CustomStringConvertible, Equatable, Hashable {
    
    case int(value: Int)
    case string(value: String)
    case uuid(value: UUID)
    
    init?(value: Any) {
        if let value = value as? Int {
            self = .int(value: value)
        } else if let value = value as? String {
            self = .string(value: value)
        } else if let value = value as? UUID {
            self = .uuid(value: value)
        } else {
           return nil
        }
    }
    
    init?(stringValue: String, attributeType: NSAttributeType) {
        switch attributeType {
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            guard let value = Int(stringValue) else { return nil }
            self = .int(value: value)
        case .UUIDAttributeType:
            guard let value = UUID(uuidString: stringValue) else { return nil }
            self = .uuid(value: value)
        case .stringAttributeType:
            self = .string(value: stringValue)
        default:
            return nil
        }
    }
    
    var description: String {
        switch self {
        case .int(let value):
            return String(value)
        case .uuid(let value):
            return value.uuidString
        case .string(let value):
            return value
        }
    }
    
    var value: CVarArg {
        switch self {
        case .int(let value):
            return NSNumber(value: value)
        case .uuid(let value):
            return value as NSUUID
        case .string(let value):
            return value
        }
    }
}
