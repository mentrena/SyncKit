//
//  CoreDataCompanyInteractor.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CoreData
import SyncKit

class CoreDataCompanyInteractor: NSObject, CompanyInteractor {
    
    let managedObjectContext: NSManagedObjectContext
    let fetchedResultsController: NSFetchedResultsController<QSCompany>
    weak var delegate: CompanyInteractorDelegate?
    let shareController: ShareController?
    
    init(managedObjectContext: NSManagedObjectContext, shareController: ShareController?) {
        self.managedObjectContext = managedObjectContext
        self.shareController = shareController
        let fetchRequest = NSFetchRequest<QSCompany>(entityName: "QSCompany")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                              managedObjectContext: managedObjectContext,
                                                              sectionNameKeyPath: nil,
                                                              cacheName: nil)
        super.init()
        fetchedResultsController.delegate = self
    }
    
    func load() {
        try? fetchedResultsController.performFetch()
        update(companies: fetchedResultsController.fetchedObjects)
    }
    
    func insertCompany(name: String) {
        let company = NSEntityDescription.insertNewObject(forEntityName: "QSCompany", into: managedObjectContext) as! QSCompany
        company.identifier = UUID().uuidString
        company.name = name
        try? managedObjectContext.save()
    }
    
    func update(companies: [QSCompany]?) {
        let translatedCompanies = companies?.map {
            Company(name: $0.name,
                    identifier: $0.identifier!,
                    isSharing: self.shareController?.isObjectShared(object: $0) ?? false,
                    isShared: false)
            } ?? []
        delegate?.didUpdateCompanies([translatedCompanies])
    }
    
    func delete(company: Company) {
        guard let com = fetchedResultsController.fetchedObjects?.first(where: {
            $0.identifier == company.identifier
        }) else { return }
        managedObjectContext.delete(com)
        try? managedObjectContext.save()
    }
    
    func fetchCompany(with company: Company) -> QSCompany? {
        return fetchedResultsController.fetchedObjects?.first(where: { (com) -> Bool in
            com.identifier == company.identifier
        })
    }
    
    func modelObject(for company: Company) -> AnyObject? {
        return fetchCompany(with: company)
    }
    
    func refreshObjects() {
        update(companies: fetchedResultsController.fetchedObjects)
    }
    
    func deleteAll() {
        guard let companies = fetchedResultsController.fetchedObjects else { return }
        managedObjectContext.perform {
            for object in companies {
                self.managedObjectContext.delete(object)
            }
            try? self.managedObjectContext.save()
        }
    }
}

extension CoreDataCompanyInteractor: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        refreshObjects()
    }
}
