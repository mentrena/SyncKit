//
//  RealmCompanyInteractor.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 26/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import RealmSwift

class RealmCompanyInteractor: CompanyInteractor {
    
    let realm: Realm
    weak var delegate: CompanyInteractorDelegate?
    let shareController: ShareController
    private var results: Results<QSCompany>!
    private var notificationToken: NotificationToken!
    
    init(realm: Realm, shareController: ShareController) {
        self.realm = realm
        self.shareController = shareController
    }
    
    func load() {
        results = realm.objects(QSCompany.self).sorted(byKeyPath: "name")
        update(companies: Array(results))
        notificationToken = results.observe({ [weak self](change) in
            guard let self = self else { return }
            self.update(companies: Array(self.results))
        })
    }
    
    func insertCompany(name: String) {
        let company = QSCompany()
        company.name = name
        company.identifier = NSUUID().uuidString
        
        realm.beginWrite()
        realm.add(company)
        try! realm.commitWrite()
    }
    
    func delete(company: Company) {
        guard let com = results?.first(where: {
            $0.identifier == company.identifier
        }) else { return }
        
        try! realm.write {
            realm.delete(com)
        }
    }
    
    func modelObject(for company: Company) -> AnyObject? {
        return results?.first(where: {
            $0.identifier == company.identifier
        })
    }
    
    func refreshObjects() {
        update(companies: Array(results))
    }
    
    func update(companies: [QSCompany]?) {
        let translatedCompanies = companies?.map {
            Company(name: $0.name,
                    identifier: $0.identifier!,
                    isSharing: self.shareController.isObjectShared(object: $0),
                    isShared: false)
            } ?? []
        delegate?.didUpdateCompanies([translatedCompanies])
    }
}
