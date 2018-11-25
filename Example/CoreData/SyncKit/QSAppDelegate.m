//
//  QSAppDelegate.m
//  SyncKit
//
//  Created by Manuel on 07/24/2016.
//  Copyright (c) 2016 Manuel. All rights reserved.
//

#import "QSAppDelegate.h"
#import "QSCompanyTableViewController.h"
#import "QSSharedCompanyTableViewController.h"
#import "QSSettingsTableViewController.h"
@import SyncKit;

@interface QSAppDelegate ()

@property (nonatomic, strong) QSCloudKitSynchronizer *synchronizer;
@property (nonatomic, strong) QSCloudKitSynchronizer *sharedSynchronizer;

@end

@implementation QSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self configureCompanyTableViewController];
    [self configureSharedCompanyVC];
    [self configureSettingsVC];
    
    return YES;
}

- (void)configureCompanyTableViewController
{
    UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
    UINavigationController *navController = (UINavigationController *)tabBarController.viewControllers[0];
    QSCompanyTableViewController *companyVC = (QSCompanyTableViewController *)navController.topViewController;
    if ([companyVC isKindOfClass:[QSCompanyTableViewController class]]) {
        [companyVC setManagedObjectContext:self.managedObjectContext];
        [companyVC setSynchronizer:self.synchronizer];
        [companyVC setAppDelegate:self];
    }
}

- (void)configureSharedCompanyVC
{
    UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
    
    UINavigationController *navController2 = (UINavigationController *)tabBarController.viewControllers[1];
    QSSharedCompanyTableViewController *sharedCompanyVC = (QSSharedCompanyTableViewController *)navController2.topViewController;
    if ([sharedCompanyVC isKindOfClass:[QSSharedCompanyTableViewController class]]) {
        [(QSSharedCompanyTableViewController *)sharedCompanyVC setSynchronizer:self.sharedSynchronizer];
    }
}

- (void)configureSettingsVC
{
    UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
    UINavigationController *navController3 = (UINavigationController *)tabBarController.viewControllers[2];
    QSSettingsTableViewController *settingsVC = (QSSettingsTableViewController *)navController3.topViewController;
    if ([settingsVC isKindOfClass:[QSSettingsTableViewController class]]) {
        
        settingsVC.privateSynchronizer = self.synchronizer;
        settingsVC.sharedSynchronizer = self.sharedSynchronizer;
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Core Data stack

@synthesize managedObjectContext = _managedObjectContext;
@synthesize sharedManagedObjectContext = _sharedManagedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize sharedPersistentStoreCoordinator = _sharedPersistentStoreCoordinator;

- (NSURL *)applicationDocumentsDirectory {
    // The directory the application uses to store the Core Data store file. This code uses a directory named "com.colourbox.cloudkittest.prueba" in the application's documents directory.
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"QSExample" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it.
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    // Create the coordinator and store
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"QSExample.sqlite"];
    _persistentStoreCoordinator = [self persistentStoreCoordinatorWithStoreURL:storeURL];
    
    return _persistentStoreCoordinator;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinatorWithStoreURL:(NSURL *)storeURL
{
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSError *error = nil;
    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        // Report any error we got.
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
        dict[NSLocalizedFailureReasonErrorKey] = failureReason;
        dict[NSUnderlyingErrorKey] = error;
        error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        // Replace this with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    _managedObjectContext = [self managedObjectContextWithCoordinator:[self persistentStoreCoordinator]];
    
    return _managedObjectContext;
}

- (NSManagedObjectContext *)managedObjectContextWithCoordinator:(NSPersistentStoreCoordinator *)coordinator
{
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    return _managedObjectContext;
}

#pragma mark - Core Data Saving support

- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

#pragma mark - Core Data Synchronizer

- (QSCloudKitSynchronizer *)synchronizer
{
    if (!_synchronizer) {
        _synchronizer = [QSCloudKitSynchronizer cloudKitPrivateSynchronizerWithContainerName:@"your-container-name" managedObjectContext:self.managedObjectContext];
    }
    return _synchronizer;
}

- (QSCloudKitSynchronizer *)sharedSynchronizer
{
    if (!_sharedSynchronizer) {
        _sharedSynchronizer = [QSCloudKitSynchronizer cloudKitSharedSynchronizerWithContainerName:@"your-container-name" objectModel:self.managedObjectModel];
    }
    return  _sharedSynchronizer;
}

#pragma mark - Accepting Shares

- (void)application:(UIApplication *)application userDidAcceptCloudKitShareWithMetadata:(CKShareMetadata *)cloudKitShareMetadata
{
    CKContainer *container = [CKContainer containerWithIdentifier:cloudKitShareMetadata.containerIdentifier];
    CKAcceptSharesOperation *acceptShareOperation = [[CKAcceptSharesOperation alloc] initWithShareMetadatas:@[cloudKitShareMetadata]];
    acceptShareOperation.qualityOfService = NSQualityOfServiceUserInteractive;
    acceptShareOperation.acceptSharesCompletionBlock = ^(NSError * _Nullable operationError) {
        if (operationError) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:@"Could not accept CloudKit share" preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
        } else {
            [self.sharedSynchronizer synchronizeWithCompletion:nil];
        }
    };
    [container addOperation:acceptShareOperation];
}

#pragma mark -

- (void)didGetChangeTokenExpiredError
{
    [self deleteAllCompanies];
    [self.synchronizer eraseLocalMetadata];
    self.synchronizer = nil;
    [self configureCompanyTableViewController];
    [self configureSettingsVC];
}

- (void)deleteAllCompanies
{
    NSArray *companies = [self.managedObjectContext executeFetchRequestWithEntityName:@"QSCompany" error:nil];
    for (NSManagedObject *object in companies) {
        [self.managedObjectContext deleteObject:object];
    }
    [self.managedObjectContext save:nil];
}

@end
