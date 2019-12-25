//
//  CoreDataCompanyWireframe.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit
import CoreData
import SyncKit

class CoreDataCompanyWireframe: CompanyWireframe {
    
    let navigationController: UINavigationController
    let managedObjectContext: NSManagedObjectContext
    let employeeWireframe: EmployeeWireframe
    let synchronizer: CloudKitSynchronizer?
    let settingsManager: SettingsManager
    init(navigationController: UINavigationController, managedObjectContext: NSManagedObjectContext, employeeWireframe: EmployeeWireframe, synchronizer: CloudKitSynchronizer?, settingsManager: SettingsManager) {
        self.navigationController = navigationController
        self.managedObjectContext = managedObjectContext
        self.employeeWireframe = employeeWireframe
        self.synchronizer = synchronizer
        self.settingsManager = settingsManager
    }
    
    func show() {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Company") as! CompanyViewController
        let interactor = CoreDataCompanyInteractor(managedObjectContext: managedObjectContext,
                                                   shareController: synchronizer)
        let presenter = DefaultCompanyPresenter(view: viewController,
                                                interactor: interactor,
                                                wireframe: self,
                                                synchronizer: synchronizer,
                                                canEdit: true,
                                                settingsManager: settingsManager)
        viewController.presenter = presenter
        interactor.delegate = presenter
        navigationController.viewControllers = [viewController]
    }
    
    func show(company: Company, canEdit: Bool) {
        employeeWireframe.show(company: company, canEdit: canEdit)
    }
}
