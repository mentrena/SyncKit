//
//  CoreDataStack.swift
//  SyncKitCoreDataExample
//
//  Created by Jérôme Haegeli on 29.07.18.
//  Copyright © 2018 Manuel. All rights reserved.
//

import SyncKit
import NotificationCenter
import CloudKit


let bundleID = Bundle.main.bundleIdentifier!
let cloudKitContainerID = "iCloud." + bundleID
let notificationID = "notification." + bundleID + ".cloudKitSync"

/// extensions to make accessing notification names global to the application
/// easier with the shorthand . notation
extension NSNotification.Name {
    
    /// the data update notification name, this notification is sent when new
    /// data is synchronized from CloudKit so that view controllers can draw
    /// the new data
    static var cloudKitSync: NSNotification.Name {
        return NSNotification.Name(rawValue: notificationID)
    }
    
}

/// The central core data stack for the application, extensions, and apple watch
/// application
class CoreDataStack: NSObject {
    
    // MARK: Singleton pattern
    
    /// The private constructor for the singleton instance
    private override init() {
        super.init()
        // load the view context to avoid some weird startup problems
        _ = persistentContainer.viewContext
    }
    
    /// the private shared instack of the stack
    private static var singleton: CoreDataStack?
    
    /// the public accessor for the shared instance
    public static var shared: CoreDataStack {
        guard let _shared = singleton else {
            singleton = CoreDataStack()
            return singleton!
        }
        return _shared
    }
    
    // MARK: CoreData Support
    
    /// The persistent container for the application. This implementation
    /// creates and returns a container, having loaded the store for the
    /// application to it. This property is optional since there are legitimate
    /// error conditions that could cause the creation of the store to fail.
    lazy var persistentContainer: NSPersistentContainer = {
        
        let container = NSPersistentContainer(name: "QSExample")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                NSLog(error.localizedDescription)
            }
        })
        return container
    }()
    
    /// Fetch all of the objects in the core store of the given type
    /// - parameters:
    ///   - of: the type of the core data entity to fetch all of
    ///   - callback: the callback function for the fetch operation
    func fetchAll(of type: NSManagedObject.Type = NSManagedObject.self) -> [NSManagedObject]? {
        let request = NSFetchRequest<NSManagedObject>(entityName: String(describing: type))
        do {
            let objects = try persistentContainer.viewContext.fetch(request)
            return objects
        } catch {
            NSLog(error.localizedDescription)
            return nil
        }
    }
    
    // MARK: Sync
    
    public var synchronizer: QSCloudKitSynchronizer?
    
    func setupSynchronizer() {
        self.synchronizer = QSCloudKitSynchronizer.cloudKitPrivateSynchronizer(withContainerName: "iCloud.ch.jeko.SyncKit", managedObjectContext: self.persistentContainer.viewContext)
    }
    
    public var sharedSynchronizer: QSCloudKitSynchronizer?
    
    func setupSharedSynchronizer() {
        self.sharedSynchronizer = QSCloudKitSynchronizer.cloudKitSharedSynchronizer(withContainerName: cloudKitContainerID, objectModel: self.persistentContainer.managedObjectModel)
    }
    
    func saveContext () {
        if persistentContainer.viewContext.hasChanges {
            do {
                try persistentContainer.viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
    
    /// Verify that an iCloud account exists with a callback if it does
    private func verifyICloud(didFindValidAccount: @escaping () -> Void) {
        CKContainer.default().accountStatus { (accountStatus, error) in
            switch accountStatus {
            case .available:
                NSLog("iCloud Available")
                didFindValidAccount()
            case .noAccount:
                NSLog("No iCloud account")
            case .restricted:
                NSLog("iCloud restricted")
            case .couldNotDetermine:
                NSLog("Unable to determine iCloud status")
            }
        }
    }
    
    
}

