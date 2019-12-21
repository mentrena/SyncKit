//
//  RealmSharedCompanyWireframe.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 26/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit
import Realm
import SyncKit

class RealmSharedCompanyWireframe: CompanyWireframe {
    let navigationController: UINavigationController
    let synchronizer: CloudKitSynchronizer
    var interactor: RealmSharedCompanyInteractor!
    let showsSync: Bool
    init(navigationController: UINavigationController, synchronizer: CloudKitSynchronizer, showsSync: Bool) {
        self.navigationController = navigationController
        self.synchronizer = synchronizer
        self.showsSync = showsSync
    }
    
    func show() {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Company") as! CompanyViewController
        interactor = RealmSharedCompanyInteractor(resultsController: synchronizer.multiRealmResultsController()!)
        let presenter = DefaultCompanyPresenter(view: viewController,
                                                interactor: interactor,
                                                wireframe: self,
                                                synchronizer: synchronizer,
                                                canEdit: false,
                                                showsSync: showsSync)
        viewController.presenter = presenter
        interactor.delegate = presenter
        navigationController.viewControllers = [viewController]
    }
    
    func show(company: Company, canEdit: Bool) {
        guard let modelObject = interactor.modelObject(for: company) as? QSCompany,
            let realm = modelObject.realm else { return }
        
        let employeeWireframe = RealmEmployeeWireframe(navigationController: navigationController, realm: realm)
        employeeWireframe.show(company: company, canEdit: canEdit)
    }
}
