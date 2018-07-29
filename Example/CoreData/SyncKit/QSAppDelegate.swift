//
//  QSAppDelegate.swift
//  SyncKit
//
//  Created by Jérôme Haegeli on 29.08.18.
//  Copyright © 2018 Manuel. All rights reserved.
//

import SyncKit
import UIKit

@UIApplicationMain
class QSAppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions:  [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        
        CoreDataStack.shared.setupSynchronizer()
        CoreDataStack.shared.setupSharedSynchronizer()
        
        // Override point for customization after application launch.
        let tabBarController = window?.rootViewController as? UITabBarController
        let navController = tabBarController?.viewControllers![0] as? UINavigationController
        let companyVC = navController?.topViewController as? QSCompanyTableViewController
        if (companyVC != nil) {
            (companyVC)?.managedObjectContext = CoreDataStack.shared.persistentContainer.viewContext
            (companyVC)?.synchronizer = CoreDataStack.shared.synchronizer
        }
        let navController2 = tabBarController?.viewControllers![1] as? UINavigationController
        let sharedCompanyVC = navController2?.topViewController as? QSSharedCompanyTableViewController
        if (sharedCompanyVC != nil) {
            (sharedCompanyVC)?.synchronizer = CoreDataStack.shared.sharedSynchronizer
        }
        let navController3 = tabBarController?.viewControllers![2] as? UINavigationController
        let settingsVC = navController3?.topViewController as? QSSettingsTableViewController
        if (settingsVC != nil) {
            settingsVC?.privateSynchronizer = CoreDataStack.shared.synchronizer
            settingsVC?.sharedSynchronizer = CoreDataStack.shared.sharedSynchronizer
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
        CoreDataStack.shared.synchronizer?.synchronize(completion: nil)
        CoreDataStack.shared.sharedSynchronizer?.synchronize(completion: nil)
        print("Remote Notification received")
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
                CoreDataStack.shared.sharedSynchronizer?.synchronize(completion: nil)
            }
        }
        container.add(acceptShareOperation)
    }
    
}
