//
//  RealmEmployeeWireframe.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 26/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import RealmSwift

class RealmEmployeeWireframe: EmployeeWireframe {
    
    let navigationController: UINavigationController
    let realm: Realm
    init(navigationController: UINavigationController, realm: Realm) {
        self.navigationController = navigationController
        self.realm = realm
    }
    
    func show(company: Company, canEdit: Bool) {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Employee") as! EmployeeViewController
        
        #if USE_INT_KEY
        let interactor = RealmEmployeeInteractor_Int(realm: realm, company: company)
        #else
        let interactor = RealmEmployeeInteractor(realm: realm, company: company)
        #endif
        
        let presenter = DefaultEmployeePresenter(view: viewController,
                                                 company: company,
                                                 interactor: interactor,
                                                 canEdit: canEdit)
        interactor.delegate = presenter
        viewController.presenter = presenter
        navigationController.pushViewController(viewController, animated: true)
    }
}
