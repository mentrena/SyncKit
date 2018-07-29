//
//  QSAppDelegate.swift
//  SyncKit
//
//  Created by Manuel on 07/24/2016.
//  Copyright (c) 2016 Manuel. All rights reserved.
//

import SyncKit
import UIKit

@UIApplicationMain
class QSAppDelegate1: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions:
        
        
        [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        // Override point for customization after application launch.
        let tabBarController = window?.rootViewController as? UITabBarController
        let navController = tabBarController?.viewControllers![0] as? UINavigationController
        let companyVC = navController?.topViewController as? QSCompanyTableViewController
        if (companyVC != nil) {
            (companyVC)?.managedObjectContext = managedObjectContext
            (companyVC)?.synchronizer = synchronizer
        }
        let navController2 = tabBarController?.viewControllers![1] as? UINavigationController
        let sharedCompanyVC = navController2?.topViewController as? QSSharedCompanyTableViewController
        if (sharedCompanyVC != nil) {
            (sharedCompanyVC)?.synchronizer = sharedSynchronizer
        }
        let navController3 = tabBarController?.viewControllers![2] as? UINavigationController
        let settingsVC = navController3?.topViewController as? QSSettingsTableViewController
        if (settingsVC != nil) {
            settingsVC?.privateSynchronizer = synchronizer
            settingsVC?.sharedSynchronizer = sharedSynchronizer
        }
        UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil))
        UIApplication.shared.registerForRemoteNotifications()
        // Handle APN on Terminated state, app launched because of APN
        let payload = launchOptions?[.remoteNotification] as? [AnyHashable : Any]
        if payload != nil {
            print(payload!)
        }
        
        return true
    }
    
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Error: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("didRegisterForRemoteNotificationsWithDeviceToken: \(deviceToken)")
    }
    
    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        print("NotificationSettings: \(notificationSettings)")
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        let cloudKitNotification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        let alertBody = cloudKitNotification.alertBody
        if cloudKitNotification.notificationType == .query {
            let recordID: CKRecordID? = (cloudKitNotification as? CKQueryNotification)?.recordID
        }
        // Detect if APN is received on Background or Foreground state
        if application.applicationState == .inactive {
            print("Application is inactive")
        } else if application.applicationState == .active {
            print("Application is active")
        }
        let pushCode = userInfo["pushCode"] as! Int
        print(String(format: "Silent Push Code Notification: %li", pushCode))
        let aps = userInfo["aps"] as? [AnyHashable : Any]
        let alertMessage = aps?["alert"] as? String
        print("alertMessage: \(alertMessage, alertBody)")
        synchronizer?.synchronize(completion: nil)
        sharedSynchronizer?.synchronize(completion: nil)
        print("Remote Notification received")
    }
    
// MARK: - Core Data stack
    
    private lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named in the application's documents Application Support directory.
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()
    
    private lazy var managedObjectModel: NSManagedObjectModel = {

        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "QSExample", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()

    private lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("QSExample.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            // Configure automatic migration.
            let options = [ NSMigratePersistentStoresAutomaticallyOption : true, NSInferMappingModelAutomaticallyOption : true ]
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject?
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {

        var managedObjectContext: NSManagedObjectContext?
        if #available(iOS 10.0, *){

            managedObjectContext = self.persistentContainer.viewContext
        }
        else{
            // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
            let coordinator = self.persistentStoreCoordinator
            managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            managedObjectContext?.persistentStoreCoordinator = coordinator
            
        }
        return managedObjectContext!
    }()
    
    // iOS-10
    @available(iOS 10.0, *)
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "QSExample")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        print("\(self.applicationDocumentsDirectory)")
        return container
    }()
    
    private(set) var sharedManagedObjectContext: NSManagedObjectContext?
    
    private(set) var sharedPersistentStoreCoordinator: NSPersistentStoreCoordinator?

// MARK: - Core Data Saving support
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
    
    
    var synchronizer: QSCloudKitSynchronizer? {

        if self.iCloudEnabledByUser() && self.iCloudAccountIsSignedIn() {
            print("** iCloud available SYNCHRONIZER! **")
        } else {
            print("** iCloud not available **")
        }

        guard let sync = QSCloudKitSynchronizer.cloudKitPrivateSynchronizer(withContainerName: "iCloud.ch.jeko.SyncKit", managedObjectContext: self.managedObjectContext) else {
            fatalError("Unable to create synchronizer")
        }
         return sync
    }
   
    var sharedSynchronizer: QSCloudKitSynchronizer? {
        
        guard let sharedSync = QSCloudKitSynchronizer.cloudKitPrivateSynchronizer(withContainerName: "iCloud.ch.jeko.SyncKit", managedObjectContext: self.managedObjectContext) else {
            fatalError("Unable to create SharedSynchronizer")
        }
        return sharedSync
    }
    
// MARK: - Accepting Shares
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShareMetadata) {
        let container = CKContainer(identifier: cloudKitShareMetadata.containerIdentifier)
        let acceptShareOperation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])
        acceptShareOperation.qualityOfService = .userInteractive
        acceptShareOperation.acceptSharesCompletionBlock = { operationError in
            if operationError != nil {
                let alertController = UIAlertController(title: "Error", message: "Could not accept CloudKit share", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.window?.rootViewController?.present(alertController, animated: true)
            } else {
                self.sharedSynchronizer?.synchronize(completion: nil)
            }
        }
        container.add(acceptShareOperation)
    }
    
// MARK: - ICLOUD
    
    let debug = 1
    
    func iCloudAccountIsSignedIn() -> Bool {
        if debug == 1 {
            print("Running \(type(of: self)) '\(NSStringFromSelector(#function))'")
        }
        let token = FileManager.default.ubiquityIdentityToken
        if token != nil {
            if let aToken = token {
                print("** iCloud is SIGNED IN with token '\(aToken)' **")
            }
            return true
        }
        return false
    }
    
    func iCloudEnabledByUser() -> Bool {
        if debug == 1 {
            print("Running \(type(of: self)) '\(NSStringFromSelector(#function))'")
        }
        UserDefaults.standard.synchronize()
        let enabled = UserDefaults.standard.object(forKey: "iCloudEnabled") as? Int
        if enabled != 0 {
            print("** iCloud is ENABLED in Settings **")
            return true
        }
        print("** iCloud is DISABLED in Settings **")
        return false
    }
    
    
    
}
