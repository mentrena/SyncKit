//
//  QSNamesTransformer.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 18/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation

class QSNamesTransformer: ValueTransformer {
    
    static var transformedValueCalled = false
    static var reverseTransformedValueCalled = false
    static func resetValues() {
        transformedValueCalled = false
        reverseTransformedValueCalled = false
    }
    
    static func register() {
        ValueTransformer.setValueTransformer(QSNamesTransformer(), forName: .namesTransformerName)
    }
    
    override class func transformedValueClass() -> AnyClass {
        NSData.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        QSNamesTransformer.transformedValueCalled = true
        return NSKeyedArchiver.archivedData(withRootObject: value)
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        QSNamesTransformer.reverseTransformedValueCalled = true
        return NSKeyedUnarchiver.unarchiveObject(with: value as! Data)
    }
}

class QSSecureNamesTransformer: NSSecureUnarchiveFromDataTransformer {

    static var transformedValueCalled = false
    static var reverseTransformedValueCalled = false
    static func resetValues() {
        transformedValueCalled = false
        reverseTransformedValueCalled = false
    }

    static func register() {
        ValueTransformer.setValueTransformer(QSSecureNamesTransformer(), forName: .secureNamesTransformerName)
    }

    override class func transformedValueClass() -> AnyClass {
        NSData.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        QSSecureNamesTransformer.transformedValueCalled = true
        return NSKeyedUnarchiver.unarchiveObject(with: value as! Data)

    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        QSSecureNamesTransformer.reverseTransformedValueCalled = true
        return NSKeyedArchiver.archivedData(withRootObject: value)
    }
}

extension NSValueTransformerName {
    static let namesTransformerName = NSValueTransformerName(rawValue: "QSNamesTransformer")
    static let secureNamesTransformerName = NSValueTransformerName(rawValue: "QSSecureNamesTransformer")
}
