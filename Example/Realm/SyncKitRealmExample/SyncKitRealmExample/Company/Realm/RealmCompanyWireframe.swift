//
//  RealmCompanyWireframe.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 26/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import Realm
import SyncKit

class RealmCompanyWireframe: CompanyWireframe {
    
    let navigationController: UINavigationController
    let realm: RLMRealm
    let employeeWireframe: EmployeeWireframe
    let synchronizer: CloudKitSynchronizer?
    let showsSync: Bool
    init(navigationController: UINavigationController, realm: RLMRealm, employeeWireframe: EmployeeWireframe, synchronizer: CloudKitSynchronizer?, showsSync: Bool) {
        self.navigationController = navigationController
        self.realm = realm
        self.employeeWireframe = employeeWireframe
        self.synchronizer = synchronizer
        self.showsSync = showsSync
    }
    
    func show() {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Company") as! CompanyViewController
        let interactor = RealmCompanyInteractor(realm: realm, shareController: synchronizer)
        let presenter = DefaultCompanyPresenter(view: viewController,
                                                interactor: interactor,
                                                wireframe: self,
                                                synchronizer: synchronizer,
                                                canEdit: true,
                                                showsSync: showsSync)
        viewController.presenter = presenter
        interactor.delegate = presenter
        navigationController.viewControllers = [viewController]
    }
    
    func show(company: Company, canEdit: Bool) {
        employeeWireframe.show(company: company, canEdit: canEdit)
    }
}
