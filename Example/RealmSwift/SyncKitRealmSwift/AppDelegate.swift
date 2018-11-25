//
//  AppDelegate.swift
//  SyncKitRealmSwift
//
//  Created by Manuel Entrena on 29/08/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import UIKit
import RealmSwift
import SyncKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
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
    
    weak var companyViewController: QSCompanyTableViewController?
    
    var realm: Realm!
    fileprivate var _synchronizer: QSCloudKitSynchronizer!
    var synchronizer: QSCloudKitSynchronizer! {
        if _synchronizer == nil {
            _synchronizer = QSCloudKitSynchronizer.cloudKitPrivateSynchronizer(containerName: "iCloud.com.mentrena.SyncKitRealmSwift", configuration: self.realmConfiguration)
        }
        return _synchronizer
    }
    fileprivate var _sharedSynchronizer: QSCloudKitSynchronizer!
    var sharedSynchronizer: QSCloudKitSynchronizer! {
        if _sharedSynchronizer == nil {
            _sharedSynchronizer = QSCloudKitSynchronizer.cloudKitSharedSynchronizer(containerName: "iCloud.com.mentrena.SyncKitRealmSwift", configuration: self.realmConfiguration)
        }
        return _sharedSynchronizer
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        realm = try! Realm(configuration: realmConfiguration)
        
        configureCompanyVC()
        configureSharedCompanyVC()
        configureSettingsVC()
        
        return true
    }
    
    func configureCompanyVC() {
        if let tabBarController = window?.rootViewController as? UITabBarController,
            let navController = tabBarController.viewControllers![0] as? UINavigationController,
            let companyVC = navController.topViewController as? QSCompanyTableViewController {
            
            companyVC.realm = realm
            companyVC.synchronizer = synchronizer
            companyVC.appDelegate = self
            companyViewController = companyVC
        }
    }
    
    func configureSharedCompanyVC() {
        if let tabBarController = window?.rootViewController as? UITabBarController,
            let navController = tabBarController.viewControllers![1] as? UINavigationController,
            let sharedCompanyVC = navController.topViewController as? QSSharedCompanyTableViewController {
            
            sharedCompanyVC.synchronizer = sharedSynchronizer
        }
    }
    
    func configureSettingsVC() {
        if let tabBarController = window?.rootViewController as? UITabBarController,
            let navController = tabBarController.viewControllers![2] as? UINavigationController,
            let settingsVC = navController.topViewController as? QSSettingsTableViewController {
            
            settingsVC.privateSynchronizer = synchronizer
            settingsVC.sharedSynchronizer = sharedSynchronizer
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    //MARK: - Accepting shares
    
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        
        let container = CKContainer(identifier: cloudKitShareMetadata.containerIdentifier)
        let acceptSharesOperation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])
        acceptSharesOperation.qualityOfService = .userInteractive
        acceptSharesOperation.acceptSharesCompletionBlock = { error in
            if let error = error {
                let alertController = UIAlertController(title: "Error", message: "Could not accept CloudKit share: \(error.localizedDescription)", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            } else {
                self.sharedSynchronizer.synchronize(completion: nil)
            }
        }
        container.add(acceptSharesOperation)
    }

    // MARK: -
    
    func didGetChangeTokenExpiredError() {
        
        companyViewController?.stopUsingRealmObjects()
        deleteAllCompanies()
        _synchronizer.eraseLocalMetadata()
        _synchronizer = nil
        configureCompanyVC()
        configureSettingsVC()
        companyViewController?.setupCompanies()
    }
    
    func deleteAllCompanies() {
        
        realm.invalidate()
        let companies = realm.objects(QSCompany.self)
        let employees = realm.objects(QSEmployee.self)
        
        try? realm.write {
            realm.delete(employees)
            realm.delete(companies)
        }
    }
}

