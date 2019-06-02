//
//  MockManagedObjectContext.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 10/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CoreData

class MockManagedObjectContext: NSManagedObjectContext {
    
    var saveCalled = false
    var performCalled = false
    var performAndWaitCalled = false
    
    var saveError: Error?
    
    override func save() throws {
        saveCalled = true
        if let error = saveError {
            throw error
        }
    }
    
    override func perform(_ block: @escaping () -> Void) {
        performCalled = true
        super.perform(block)
    }
    
    override func performAndWait(_ block: () -> Void) {
        performAndWaitCalled = true
        super.performAndWait(block)
    }
}
