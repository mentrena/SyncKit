//
//  AppDelegate.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 08/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit
import CoreData
import SyncKit
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var coreDataStack: CoreDataStack!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        loadCoreData()
        
        let tabBarController: UITabBarController! = window?.rootViewController as? UITabBarController
        let navigationController: UINavigationController! = tabBarController.viewControllers?[0] as? UINavigationController
        let sharedNavigationController: UINavigationController! = tabBarController.viewControllers?[1] as? UINavigationController
        let employeeWireframe = CoreDataEmployeeWireframe(navigationController: navigationController,
                                                          managedObjectContext: coreDataStack.managedObjectContext)
        let coreDataWireframe = CoreDataCompanyWireframe(navigationController: navigationController,
                                                         managedObjectContext: coreDataStack.managedObjectContext,
                                                         employeeWireframe: employeeWireframe,
                                                         synchronizer: synchronizer)
        let coreDataSharedWireframe = CoreDataSharedCompanyWireframe(navigationController: sharedNavigationController,
                                                                     synchronizer: sharedSynchronizer)
        coreDataWireframe.show()
        coreDataSharedWireframe.show()
        
        let settingsNavigationController: UINavigationController! = tabBarController.viewControllers?[2] as? UINavigationController
        let settingsViewController = settingsNavigationController.topViewController as? SettingsViewController
        settingsViewController?.privateSynchronizer = synchronizer
        
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        try? coreDataStack.managedObjectContext.save()
    }

    // MARK: - Core Data stack
    
    func loadCoreData() {
        let modelURL = Bundle.main.url(forResource: "QSExample", withExtension: "momd")
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL!)!
        let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("QSExample.sqlite")
        coreDataStack = CoreDataStack(storeType: NSSQLiteStoreType,
                                      model: managedObjectModel,
                                      storeURL: storeURL!)
    }
    
    lazy var synchronizer = CloudKitSynchronizer.privateSynchronizer(containerName: "your-iCloud-container-name",
                                                                     managedObjectContext: self.coreDataStack.managedObjectContext)
    
    lazy var sharedSynchronizer = CloudKitSynchronizer.sharedSynchronizer(containerName: "your-iCloud-container-name",
                                                                          objectModel: self.coreDataStack.model)
    
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        let container = CKContainer(identifier: cloudKitShareMetadata.containerIdentifier)
        let acceptSharesOperation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])
        acceptSharesOperation.qualityOfService = .userInteractive
        acceptSharesOperation.acceptSharesCompletionBlock = { [weak self] error in
            if let error = error {
                let alertController = UIAlertController(title: "Error", message: "\(error.localizedDescription)", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.window?.rootViewController?.present(alertController, animated: true, completion: nil)
            } else {
                self?.sharedSynchronizer.synchronize(completion: nil)
            }
        }
        container.add(acceptSharesOperation)
    }
    
}

