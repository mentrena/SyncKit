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
    var settingsManager = SettingsManager()
    var settingsViewController: SettingsViewController?
    
    var synchronizer: CloudKitSynchronizer?
    lazy var sharedSynchronizer = CloudKitSynchronizer.sharedSynchronizer(containerName: "your-iCloud-container",
                                                                          objectModel: self.coreDataStack.model)

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        settingsManager.delegate = self
        loadCoreData()
        loadSyncKit()
        loadPrivateModule()
        loadSharedModule()
        loadSettingsModule()
        
        return true
    }
    
    func loadPrivateModule() {
        let tabBarController: UITabBarController! = window?.rootViewController as? UITabBarController
        let navigationController: UINavigationController! = tabBarController.viewControllers?[0] as? UINavigationController
        
        let employeeWireframe = CoreDataEmployeeWireframe(navigationController: navigationController,
                                                          managedObjectContext: coreDataStack.managedObjectContext)
        let coreDataWireframe = CoreDataCompanyWireframe(navigationController: navigationController,
                                                         managedObjectContext: coreDataStack.managedObjectContext,
                                                         employeeWireframe: employeeWireframe,
                                                         synchronizer: synchronizer,
                                                         settingsManager: settingsManager)
        coreDataWireframe.show()
    }
    
    func loadSharedModule() {
        let tabBarController: UITabBarController! = window?.rootViewController as? UITabBarController
        let sharedNavigationController: UINavigationController! = tabBarController.viewControllers?[1] as? UINavigationController
        let coreDataSharedWireframe = CoreDataSharedCompanyWireframe(navigationController: sharedNavigationController,
                                                                     synchronizer: sharedSynchronizer,
                                                                     settingsManager: settingsManager)
        coreDataSharedWireframe.show()
    }
    
    func loadSettingsModule() {
        let tabBarController: UITabBarController! = window?.rootViewController as? UITabBarController
        let settingsNavigationController: UINavigationController! = tabBarController.viewControllers?[2] as? UINavigationController
        settingsViewController = settingsNavigationController.topViewController as? SettingsViewController
        settingsViewController?.privateSynchronizer = synchronizer
        settingsViewController?.settingsManager = settingsManager
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
    
    func loadSyncKit() {
        if settingsManager.isSyncEnabled {
            synchronizer = CloudKitSynchronizer.privateSynchronizer(containerName: "your-iCloud-container",
                                                                    managedObjectContext: self.coreDataStack.managedObjectContext)
        }
    }
    
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

extension AppDelegate: SettingsManagerDelegate {
    func didSetSyncEnabled(value: Bool) {
        if value == false {
            synchronizer?.eraseLocalMetadata()
            synchronizer = nil
            settingsViewController?.privateSynchronizer = nil
            loadPrivateModule()
        } else {
            connectSyncKit()
        }
    }
    
    func connectSyncKit() {
        let alertController = UIAlertController(title: "Connecting CloudKit", message: "Would you like to bring existing data into CloudKit?", preferredStyle: .alert)
        let keepData = UIAlertAction(title: "Keep existing data", style: .default) { (_) in
            self.createNewSynchronizer()
        }
        
        let removeData = UIAlertAction(title: "No", style: .destructive) { (_) in
            let interactor = CoreDataCompanyInteractor(managedObjectContext: self.coreDataStack.managedObjectContext,
                                                       shareController: nil)
            interactor.load()
            interactor.deleteAll()
            self.createNewSynchronizer()
        }
        alertController.addAction(keepData)
        alertController.addAction(removeData)
        settingsViewController?.present(alertController, animated: true, completion: nil)
    }
    
    func createNewSynchronizer() {
        loadSyncKit()
        settingsViewController?.privateSynchronizer = synchronizer
        loadPrivateModule()
    }
}
 
