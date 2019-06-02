//
//  CompanyInteractor.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import SyncKit

protocol CompanyInteractor {
    func load()
    func insertCompany(name: String)
    func delete(company: Company)
    func modelObject(for company: Company) -> AnyObject?
    func refreshObjects()
}

protocol CompanyInteractorDelegate: class {
    func didUpdateCompanies(_ companies: [[Company]])
}

protocol ShareController {
    func isObjectShared(object: AnyObject) -> Bool
}

extension CloudKitSynchronizer: ShareController {
    func isObjectShared(object: AnyObject) -> Bool {
        return share(for: object) != nil
    }
}
