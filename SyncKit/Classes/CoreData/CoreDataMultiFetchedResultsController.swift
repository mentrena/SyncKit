//
//  CoreDataMultiFetchedResultsController.swift
//  SyncKit
//
//  Created by Manuel Entrena on 08/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

@objc public protocol CoreDataMultiFetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate {
    func multiFetchedResultsControllerDidChangeControllers(_ controller: CoreDataMultiFetchedResultsController)
}

@objc public class CoreDataMultiFetchedResultsController: NSObject {
    @objc public weak var delegate: CoreDataMultiFetchedResultsControllerDelegate?
    @objc public private(set) var fetchedResultsControllers: [NSFetchedResultsController<NSFetchRequestResult>]!
    @objc public let fetchRequest: NSFetchRequest<NSFetchRequestResult>
    @objc public let provider: DefaultCoreDataStackProvider
    
    private var controllersPerZoneID = [CKRecordZone.ID: NSFetchedResultsController<NSFetchRequestResult>]()

    @objc public init(stackProvider: DefaultCoreDataStackProvider, fetchRequest: NSFetchRequest<NSFetchRequestResult>) {
        self.fetchRequest = fetchRequest
        self.provider = stackProvider
        super.init()
        stackProvider.delegate = self
        updateFetchedResultsControllers()
    }
    
    func updateFetchedResultsControllers() {
        
        var controllers = [NSFetchedResultsController<NSFetchRequestResult>]()
        provider.adapterDictionary.forEach { (zoneID, adapter) in
            let fetchedResultsController = self.createFetchedResultsController(for: adapter)
            controllersPerZoneID[zoneID] = fetchedResultsController
            controllers.append(fetchedResultsController)
        }
        fetchedResultsControllers = controllers
    }
    
    func createFetchedResultsController(for adapter: CoreDataAdapter) -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: adapter.targetContext, sectionNameKeyPath: nil, cacheName: nil)
        try? fetchedResultsController.performFetch()
        fetchedResultsController.delegate = delegate
        return fetchedResultsController
    }
}

extension CoreDataMultiFetchedResultsController: DefaultCoreDataStackProviderDelegate {
    public func provider(_ provider: DefaultCoreDataStackProvider, didAddAdapter adapter: CoreDataAdapter, forZoneID zoneID: CKRecordZone.ID) {
        let newController = createFetchedResultsController(for: adapter)
        fetchedResultsControllers.append(newController)
        controllersPerZoneID[zoneID] = newController
        
        DispatchQueue.main.async {
            self.delegate?.multiFetchedResultsControllerDidChangeControllers(self)
        }
    }
    
    public func provider(_ provider: DefaultCoreDataStackProvider, didRemoveAdapterForZoneID zoneID: CKRecordZone.ID) {
        if let removedController = controllersPerZoneID[zoneID],
            let index = fetchedResultsControllers.firstIndex(of: removedController){
            
            fetchedResultsControllers.remove(at: index)
            controllersPerZoneID.removeValue(forKey: zoneID)
            
            DispatchQueue.main.async {
                self.delegate?.multiFetchedResultsControllerDidChangeControllers(self)
            }
        }
    }
}
