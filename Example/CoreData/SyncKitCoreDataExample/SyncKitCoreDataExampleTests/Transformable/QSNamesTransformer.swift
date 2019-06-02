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
        return NSData.self
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

extension NSValueTransformerName {
    static let namesTransformerName = NSValueTransformerName(rawValue: "QSNamesTransformer")
}
