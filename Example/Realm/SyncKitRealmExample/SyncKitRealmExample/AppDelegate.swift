//
//  AppDelegate.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 08/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit
import Realm
import SyncKit
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var realm: RLMRealm!
    var settingsManager = SettingsManager()
    var settingsViewController: SettingsViewController?
    
    var synchronizer: CloudKitSynchronizer?
    lazy var sharedSynchronizer = CloudKitSynchronizer.sharedSynchronizer(containerName: "your-iCloud-container", configuration: self.realmConfiguration)

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        settingsManager.delegate = self
        loadRealm()
        loadSyncKit()
        loadPrivateModule()
        loadSharedModule()
        loadSettingsModule()
        
        return true
    }
    
    func loadSyncKit() {
        if settingsManager.isSyncEnabled {
            // For Extension test (app groups):
            // synchronizer = CloudKitSynchronizer.privateSynchronizer(containerName: "your-iCloud-container", configuration: self.realmConfiguration, suiteName: "group.com.mentrena.todayextensiontest")
            synchronizer = CloudKitSynchronizer.privateSynchronizer(containerName: "your-iCloud-container", configuration: self.realmConfiguration)
        }
    }
    
    func loadPrivateModule() {
        let tabBarController: UITabBarController! = window?.rootViewController as? UITabBarController
        let navigationController: UINavigationController! = tabBarController.viewControllers?[0] as? UINavigationController
        let employeeWireframe = RealmEmployeeWireframe(navigationController: navigationController,
                                                          realm: realm)
        let companyWireframe = RealmCompanyWireframe(navigationController: navigationController,
                                                         realm: realm,
                                                         employeeWireframe: employeeWireframe,
                                                         synchronizer: synchronizer,
                                                         settingsManager: settingsManager)
        companyWireframe.show()
    }
    
    func loadSharedModule() {
        let tabBarController: UITabBarController! = window?.rootViewController as? UITabBarController
        let sharedNavigationController: UINavigationController! = tabBarController.viewControllers?[1] as? UINavigationController
        let realmSharedWireframe = RealmSharedCompanyWireframe(navigationController: sharedNavigationController,
                                                               synchronizer: sharedSynchronizer,
                                                               settingsManager: settingsManager)
        realmSharedWireframe.show()
    }
    
    func loadSettingsModule() {
        let tabBarController: UITabBarController! = window?.rootViewController as? UITabBarController
        let settingsNavigationController: UINavigationController! = tabBarController.viewControllers?[2] as? UINavigationController
        settingsViewController = settingsNavigationController.topViewController as? SettingsViewController
        settingsViewController?.settingsManager = settingsManager
        settingsViewController?.privateSynchronizer = synchronizer
    }

    // MARK: - Core Data stack
    
    func loadRealm() {
        realm = try! RLMRealm(configuration: realmConfiguration)
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
    
    lazy var realmConfiguration: RLMRealmConfiguration = {
        let configuration = RLMRealmConfiguration()
        configuration.schemaVersion = 1
        configuration.migrationBlock = { migration, oldSchemaVersion in
            
            if (oldSchemaVersion < 1) {
            }
        }
        
        configuration.objectClasses = [QSCompany.self, QSEmployee.self]
        return configuration
    }()
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
            let interactor = RealmCompanyInteractor(realm: self.realm,
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
