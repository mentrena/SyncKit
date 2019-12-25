//
//  CoreDataSharedCompanyWireframe.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 23/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import SyncKit
import CoreData

class CoreDataSharedCompanyWireframe: CompanyWireframe {
    
    let navigationController: UINavigationController
    let synchronizer: CloudKitSynchronizer
    var interactor: CoreDataSharedCompanyInteractor!
    let settingsManager: SettingsManager
    init(navigationController: UINavigationController, synchronizer: CloudKitSynchronizer, settingsManager: SettingsManager) {
        self.navigationController = navigationController
        self.synchronizer = synchronizer
        self.settingsManager = settingsManager
    }
    
    func show() {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Company") as! CompanyViewController
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "QSCompany")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let fetchedResultsController = synchronizer.multiFetchedResultsController(fetchRequest: fetchRequest)
        interactor = CoreDataSharedCompanyInteractor(fetchedResultsController: fetchedResultsController!)
        let presenter = DefaultCompanyPresenter(view: viewController,
                                                interactor: interactor,
                                                wireframe: self,
                                                synchronizer: synchronizer,
                                                canEdit: false,
                                                settingsManager: settingsManager)
        viewController.presenter = presenter
        interactor.delegate = presenter
        navigationController.viewControllers = [viewController]
    }
    
    func show(company: Company, canEdit: Bool) {
        guard let modelObject = interactor.modelObject(for: company) as? QSCompany,
            let managedObjectContext = modelObject.managedObjectContext else { return }
        
        let employeeWireframe = CoreDataEmployeeWireframe(navigationController: navigationController, managedObjectContext: managedObjectContext)
        employeeWireframe.show(company: company, canEdit: canEdit)
    }
}
