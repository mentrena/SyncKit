//
//  NSManagedObjectContext+Fetch.swift
//  Pods-CoreDataExample
//
//  Created by Manuel Entrena on 25/04/2019.
//

import Foundation
import CoreData

extension NSManagedObjectContext {
    
    public func executeFetchRequest(entityName: String,
                                    predicate: NSPredicate? = nil,
                                    fetchLimit: Int? = nil,
                                    resultType: NSFetchRequestResultType = .managedObjectResultType,
                                    propertiesToFetch: [String]? = nil,
                                    includesSubentities: Bool = false,
                                    preload: Bool = false) throws -> [NSFetchRequestResult] {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: self)
        fetchRequest.entity = entity
        fetchRequest.resultType = resultType
        fetchRequest.predicate = predicate
        fetchRequest.includesSubentities = includesSubentities
        if preload {
            fetchRequest.returnsObjectsAsFaults = false
        }
        if let limit = fetchLimit {
            fetchRequest.fetchLimit = limit
        }
        if let properties = propertiesToFetch {
            fetchRequest.propertiesToFetch = properties
        }
        
        return try fetch(fetchRequest)
    }
}
