//
//  QSManagedObjectContext.swift
//  OCMock
//
//  Created by Manuel Entrena on 15/06/2019.
//

import Foundation
import CoreData

class QSManagedObjectContext: NSManagedObjectContext {
    
    override func perform(_ block: @escaping () -> Void) {
        performAndWait(block)
    }
}
