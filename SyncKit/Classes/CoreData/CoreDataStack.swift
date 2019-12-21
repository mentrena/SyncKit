//
//  CoreDataStack.swift
//  SyncKit
//
//  Created by Manuel Entrena on 02/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CoreData

@objc public class CoreDataStack: NSObject {
    
    @objc public private(set) var managedObjectContext: NSManagedObjectContext!
    @objc public private(set) var persistentStoreCoordinator: NSPersistentStoreCoordinator!
    @objc public private(set) var store: NSPersistentStore!
    
    @objc public let storeType: String
    @objc public let storeURL: URL?
    @objc public let useDispatchImmediately: Bool
    @objc public let model: NSManagedObjectModel
    @objc public let concurrencyType: NSManagedObjectContextConcurrencyType
    
    @objc public init(storeType: String,
         model: NSManagedObjectModel,
         storeURL: URL?,
         concurrencyType: NSManagedObjectContextConcurrencyType = .privateQueueConcurrencyType,
         dispatchImmediately: Bool = false) {
        self.storeType = storeType
        self.storeURL = storeURL
        self.useDispatchImmediately = dispatchImmediately
        self.model = model
        self.concurrencyType = concurrencyType
        super.init()
        initializeStack()
        loadStore()
    }
    
    @objc public func deleteStore() {
        managedObjectContext.performAndWait {
            self.managedObjectContext.reset()
        }
        
        try? persistentStoreCoordinator.remove(store)
        managedObjectContext = nil
        store = nil
        if let url = storeURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    private func ensureStoreDirectoryExists() {
        guard let storeURL = storeURL else { return }
        let storeDirectory = storeURL.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: storeDirectory.path) == false {
            try! FileManager.default.createDirectory(at: storeDirectory,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        }
    }
    
    private func initializeStack() {
        ensureStoreDirectoryExists()
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        if useDispatchImmediately {
            managedObjectContext = QSManagedObjectContext(concurrencyType: concurrencyType)
        } else {
            managedObjectContext = NSManagedObjectContext(concurrencyType: concurrencyType)
        }
        managedObjectContext.performAndWait {
            self.managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
            self.managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
    }
    
    private func loadStore() {
        guard store == nil else { return }
        
        let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                       NSInferMappingModelAutomaticallyOption: true]
        store = try! persistentStoreCoordinator.addPersistentStore(ofType: storeType,
                                                                   configurationName: nil,
                                                                   at: storeURL,
                                                                   options: options)
    }
}
