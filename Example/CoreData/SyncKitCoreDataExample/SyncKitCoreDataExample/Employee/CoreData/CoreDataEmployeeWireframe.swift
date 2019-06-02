//
//  CoreDataEmployeeWireframe.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit
import CoreData

class CoreDataEmployeeWireframe: EmployeeWireframe {
    
    let navigationController: UINavigationController
    let managedObjectContext: NSManagedObjectContext
    init(navigationController: UINavigationController, managedObjectContext: NSManagedObjectContext) {
        self.navigationController = navigationController
        self.managedObjectContext = managedObjectContext
    }
    
    func show(company: Company, canEdit: Bool) {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Employee") as! EmployeeViewController
        let interactor = CoreDataEmployeeInteractor(managedObjectContext: managedObjectContext,
                                                    company: company)
        let presenter = DefaultEmployeePresenter(view: viewController,
                                                 company: company,
                                                 interactor: interactor,
                                                 canEdit: canEdit)
        interactor.delegate = presenter
        viewController.presenter = presenter
        navigationController.pushViewController(viewController, animated: true)
    }
}
