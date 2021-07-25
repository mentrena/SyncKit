//
//  RealmSharedCompanyInteractor.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 26/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import Realm
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
        update(companySections: resultsController.results)
    }
    
    func insertCompany(name: String) {
        
    }
    
    func delete(company: Company) {
        
    }
    
    func modelObject(for company: Company) -> AnyObject? {
        for results in resultsController.results {
            for object in results {
                let modelObject = object as! QSCompany
                if modelObject.identifier == company.identifier.stringValue {
                    return modelObject
                }
            }
        }
        return nil
    }
    
    func refreshObjects() {
        update(companySections: resultsController.results)
    }
    
    func update(companySections: [RLMResults<QSCompany>]) {
        let translatedCompanies = companySections.map { companies in
            companies.map { object -> Company in
                let com = object as! QSCompany
                return Company(name: com.name,
                               identifier: Identifier.string(value: com.identifier),
                               isSharing: false,
                               isShared: true)
            }
        }
        delegate?.didUpdateCompanies(translatedCompanies)
    }
}
