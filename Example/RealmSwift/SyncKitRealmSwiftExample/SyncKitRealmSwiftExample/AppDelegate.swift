//
//  AppDelegate.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 08/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit
import RealmSwift
import SyncKit
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var realm: Realm!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        loadRealm()
        
        let tabBarController: UITabBarController! = window?.rootViewController as? UITabBarController
        let navigationController: UINavigationController! = tabBarController.viewControllers?[0] as? UINavigationController
        let sharedNavigationController: UINavigationController! = tabBarController.viewControllers?[1] as? UINavigationController
        let employeeWireframe = RealmEmployeeWireframe(navigationController: navigationController,
                                                          realm: realm)
        let companyWireframe = RealmCompanyWireframe(navigationController: navigationController,
                                                         realm: realm,
                                                         employeeWireframe: employeeWireframe,
                                                         synchronizer: synchronizer)
        let realmSharedWireframe = RealmSharedCompanyWireframe(navigationController: sharedNavigationController,
                                                                  synchronizer: sharedSynchronizer)
        companyWireframe.show()
        realmSharedWireframe.show()
        
        let settingsNavigationController: UINavigationController! = tabBarController.viewControllers?[2] as? UINavigationController
        let settingsViewController = settingsNavigationController.topViewController as? SettingsViewController
        settingsViewController?.privateSynchronizer = synchronizer
        
        return true
    }

    // MARK: - Core Data stack
    
    func loadRealm() {
        realm = try! Realm(configuration: realmConfiguration)
    }
    
    lazy var synchronizer = CloudKitSynchronizer.privateSynchronizer(containerName: "your-iCloud-container-name", configuration: self.realmConfiguration)
    
    lazy var sharedSynchronizer = CloudKitSynchronizer.sharedSynchronizer(containerName: "your-iCloud-container-name", configuration: self.realmConfiguration)
    
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
    
    lazy var realmConfiguration: Realm.Configuration = {
        var configuration = Realm.Configuration()
        configuration.schemaVersion = 1
        configuration.migrationBlock = { migration, oldSchemaVersion in
            
            if (oldSchemaVersion < 1) {
            }
        }
        
        configuration.objectTypes = [QSCompany.self, QSEmployee.self]
        return configuration
    }()
}

