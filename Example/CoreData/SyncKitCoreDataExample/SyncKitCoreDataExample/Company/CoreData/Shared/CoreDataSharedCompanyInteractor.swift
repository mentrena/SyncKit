//
//  CoreDataMultiCompanyInteractor.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 23/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CoreData
import SyncKit

class CoreDataSharedCompanyInteractor: NSObject {

    let fetchedResultsController: CoreDataMultiFetchedResultsController
    weak var delegate: CompanyInteractorDelegate?
    init(fetchedResultsController: CoreDataMultiFetchedResultsController) {
        self.fetchedResultsController = fetchedResultsController
        super.init()
        fetchedResultsController.delegate = self
    }
    
    func update(companies: [[QSCompany]]?) {
        let translatedCompanies = companies?.map {
            $0.map {
                Company(name: $0.name,
                        identifier: Identifier.string(value: $0.identifier!),
                        isSharing: false,
                        isShared: true)
            }
        } ?? []
        delegate?.didUpdateCompanies(translatedCompanies)
    }
}

extension CoreDataSharedCompanyInteractor: CompanyInteractor {
    func load() {
        update(companies: fetchedResultsController.fetchedResultsControllers.map { $0.fetchedObjects as? [QSCompany] ?? [] })
    }
    
    func insertCompany(name: String) {
        
    }
    
    func delete(company: Company) {
        
    }
    
    func modelObject(for company: Company) -> AnyObject? {
        return fetchedResultsController.fetchedResultsControllers.flatMap { $0.fetchedObjects as? [QSCompany] ?? [] }.first {
            $0.identifier == company.identifier.stringValue
        }
    }
    
    func refreshObjects() {
        update(companies: fetchedResultsController.fetchedResultsControllers.map { $0.fetchedObjects as? [QSCompany] ?? [] })
    }
}

extension CoreDataSharedCompanyInteractor: CoreDataMultiFetchedResultsControllerDelegate {
    func multiFetchedResultsControllerDidChangeControllers(_ controller: CoreDataMultiFetchedResultsController) {
        update(companies: fetchedResultsController.fetchedResultsControllers.map { $0.fetchedObjects as? [QSCompany] ?? [] })
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        update(companies: fetchedResultsController.fetchedResultsControllers.map { $0.fetchedObjects as? [QSCompany] ?? [] })
    }
}
