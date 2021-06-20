//
//  RealmSharedCompanyInteractor.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 26/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import RealmSwift
import SyncKit

class RealmSharedCompanyInteractor: CompanyInteractor {

    weak var delegate: CompanyInteractorDelegate?
    let resultsController: MultiRealmResultsController<QSCompany>
    var token: MultiRealmObserver!
    
    init(resultsController: MultiRealmResultsController<QSCompany>) {
        self.resultsController = resultsController
        
        token = resultsController.observe { [weak self] (change) in
            switch change {
            case .error(_):
                break
            case .update(_, _, _, _):
                self?.refreshObjects()
                break
            }
        }
        
        resultsController.didChangeRealms = { [weak self] _ in
            self?.refreshObjects()
        }
    }
    
    func load() {
        update(companySections: resultsController.results.map { Array($0) })
    }
    
    func insertCompany(name: String) {
        
    }
    
    func delete(company: Company) {
        
    }
    
    func modelObject(for company: Company) -> AnyObject? {
        guard case .string(let id) = company.identifier else { return nil }
        
        for results in resultsController.results {
            for object in results {
                if object.identifier == id {
                    return object
                }
            }
        }
        return nil
    }
    
    func refreshObjects() {
        update(companySections: resultsController.results.map { Array($0) })
    }
    
    func update(companySections: [[QSCompany]]) {
        let translatedCompanies = companySections.map { companies in
            companies.map {
                Company(name: $0.name,
                        identifier: .string(value: $0.identifier),
                        isSharing: false,
                        isShared: true)
            }
        }
        delegate?.didUpdateCompanies(translatedCompanies)
    }
}
