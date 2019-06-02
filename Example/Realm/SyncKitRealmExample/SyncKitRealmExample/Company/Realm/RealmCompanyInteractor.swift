//
//  RealmCompanyInteractor.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 26/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import Realm

class RealmCompanyInteractor: CompanyInteractor {
    
    let realm: RLMRealm
    weak var delegate: CompanyInteractorDelegate?
    let shareController: ShareController
    private var results: RLMResults<QSCompany>!
    private var notificationToken: RLMNotificationToken!
    
    init(realm: RLMRealm, shareController: ShareController) {
        self.realm = realm
        self.shareController = shareController
    }
    
    func load() {
        results = QSCompany.allObjects(in: realm).sortedResults(usingKeyPath: "name", ascending: true) as? RLMResults<QSCompany>
        update(companies: results)
        notificationToken = results.addNotificationBlock({ [weak self](_, _, _) in
            guard let self = self else { return }
            self.update(companies: self.results)
        })
    }
    
    func insertCompany(name: String) {
        let company = QSCompany()
        company.name = name
        company.identifier = NSUUID().uuidString
        
        realm.beginWriteTransaction()
        realm.add(company)
        try! realm.commitWriteTransaction()
    }
    
    func delete(company: Company) {
        guard let com = results?.first(where: {
            ($0 as? QSCompany)?.identifier == company.identifier
        }) else { return }
        
        realm.beginWriteTransaction()
        realm.delete(com)
        try! realm.commitWriteTransaction()
    }
    
    func modelObject(for company: Company) -> AnyObject? {
        return results?.first(where: {
            ($0 as? QSCompany)?.identifier == company.identifier
        })
    }
    
    func refreshObjects() {
        update(companies: results)
    }
    
    func update(companies: RLMResults<QSCompany>?) {
        let translatedCompanies = companies?.map {
            Company(name: $0.name,
                    identifier: $0.identifier!,
                    isSharing: self.shareController.isObjectShared(object: $0),
                    isShared: false)
            } ?? []
        delegate?.didUpdateCompanies([translatedCompanies])
    }
}
