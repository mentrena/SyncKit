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
    
    /// Called by the multi-controller when the list of internal controllers changed. E.g. a model adapter was added or removed, which will happen when a new record zone is shared with this user for example if the user accepts a share.
    /// - Parameter controller: `CoreDataMultiFetchedResultsController`
    func multiFetchedResultsControllerDidChangeControllers(_ controller: CoreDataMultiFetchedResultsController)
}


/**
 * A `CoreDataMultiFetchedResultsController` allows to fetch objects with a fetch request across multiple `NSManagedObjectContext` instances.
 * It can be useful when getting results out of a shared synchronizer, since objects from different record zones will be kept in different Core Data contexts.
 */
@objc public class CoreDataMultiFetchedResultsController: NSObject {
    
    /// A delegate to be called when the internal controllers change as a result of new shared being accepted/removed.
    @objc public weak var delegate: CoreDataMultiFetchedResultsControllerDelegate?
    
    /// List of `NSFetchedResultsController` used to get the results.
    @objc public private(set) var fetchedResultsControllers: [NSFetchedResultsController<NSFetchRequestResult>]!
    
    /// Fetch request used to get the results.
    @objc public let fetchRequest: NSFetchRequest<NSFetchRequestResult>
    
    /// `DefaultCoreDataStackProvider` linked to this controller. This is the object that provides a new Core Data stack to the synchronizer when a new record zone is added to it –user accepted a share, for example.
    @objc public let provider: DefaultCoreDataStackProvider
    
    private var controllersPerZoneID = [CKRecordZone.ID: NSFetchedResultsController<NSFetchRequestResult>]()

    
    /// Createa a new controller with results from the contexts in the given stack provider.
    /// - Parameters:
    ///   - stackProvider: The Core Data stack provider that contains the contexts to get results from.
    ///   - fetchRequest: Fetch request to use to with Core Data to get the objects.
    @objc public init(stackProvider: DefaultCoreDataStackProvider, fetchRequest: NSFetchRequest<NSFetchRequestResult>) {
        self.fetchRequest = fetchRequest
        self.provider = stackProvider
        super.init()
        configureNotifications()
        
        updateFetchedResultsControllers()
    }
    
    func configureNotifications() {
        NotificationCenter.default.addObserver(forName: .CoreDataStackProviderDidAddAdapterNotification, object: provider, queue: nil) { [weak self] (notification) in
            
            guard let self = self,
                  let userInfo = notification.userInfo as? [CKRecordZone.ID: CoreDataAdapter] else { return }
            userInfo.forEach({ (zoneID, adapter) in
                self.provider(self.provider, didAddAdapter: adapter, forZoneID: zoneID)
            })
        }
        
        NotificationCenter.default.addObserver(forName: .CoreDataStackProviderDidRemoveAdapterNotification, object: provider, queue: nil) { [weak self] (notification) in
        
            guard let self = self,
                  let userInfo = notification.userInfo as? [CKRecordZone.ID: CoreDataAdapter] else { return }
            userInfo.forEach({ (zoneID, adapter) in
                self.provider(self.provider, didRemoveAdapterForZoneID: zoneID)
            })
        }
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

extension CoreDataMultiFetchedResultsController {
    func provider(_ provider: DefaultCoreDataStackProvider, didAddAdapter adapter: CoreDataAdapter, forZoneID zoneID: CKRecordZone.ID) {
        let newController = createFetchedResultsController(for: adapter)
        fetchedResultsControllers.append(newController)
        controllersPerZoneID[zoneID] = newController
        
        DispatchQueue.main.async {
            self.delegate?.multiFetchedResultsControllerDidChangeControllers(self)
        }
    }
    
    func provider(_ provider: DefaultCoreDataStackProvider, didRemoveAdapterForZoneID zoneID: CKRecordZone.ID) {
        if let removedController = controllersPerZoneID[zoneID],
            let index = fetchedResultsControllers.firstIndex(of: removedController) {
            
            fetchedResultsControllers.remove(at: index)
            controllersPerZoneID.removeValue(forKey: zoneID)
            
            DispatchQueue.main.async {
                self.delegate?.multiFetchedResultsControllerDidChangeControllers(self)
            }
        }
    }
}
