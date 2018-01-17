//
//  AppDelegate.m
//  SyncKitRealm
//
//  Created by Manuel Entrena on 04/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import "AppDelegate.h"
#import <Realm/Realm.h>
#import <SyncKit/QSCloudKitSynchronizer+Realm.h>
#import "QSCompanyTableViewController.h"
#import "QSSharedCompanyTableViewController.h"
#import "QSSettingsTableViewController.h"
#import "QSCompany.h"
#import "QSEmployee.h"

@interface AppDelegate () <UISplitViewControllerDelegate>

@property (nonatomic, strong) RLMRealmConfiguration *configuration;
@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) QSCloudKitSynchronizer *synchronizer;
@property (nonatomic, strong) QSCloudKitSynchronizer *sharedSynchronizer;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    

    self.realm = [RLMRealm realmWithConfiguration:self.configuration error:nil];
    UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
    UINavigationController *companyNavController = (UINavigationController *)tabBarController.viewControllers.firstObject;
    QSCompanyTableViewController *companyVC = (QSCompanyTableViewController *)companyNavController.topViewController;
    if ([companyVC isKindOfClass:[QSCompanyTableViewController class]]) {
        [companyVC setRealm:self.realm];
        [companyVC setSynchronizer:self.synchronizer];
    }
    UINavigationController *sharedNavController = (UINavigationController *)tabBarController.viewControllers[1];
    QSSharedCompanyTableViewController *sharedCompanyVC = (QSSharedCompanyTableViewController *)sharedNavController.topViewController;
    if ([sharedCompanyVC isKindOfClass:[QSSharedCompanyTableViewController class]]) {
        [sharedCompanyVC setSynchronizer:self.sharedSynchronizer];
    }
    UINavigationController *settingsNavController = (UINavigationController *)tabBarController.viewControllers[2];
    QSSettingsTableViewController *settingsVC = (QSSettingsTableViewController *)settingsNavController.topViewController;
    if ([settingsVC isKindOfClass:[QSSettingsTableViewController class]]) {
        settingsVC.privateSynchronizer = self.synchronizer;
        settingsVC.sharedSynchronizer = self.sharedSynchronizer;
    }
    return YES;
}

//- (NSURL *)realmPath
//{
//     NSURL *groupURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.mentrena.todayextensiontest"];
//    return [groupURL URLByAppendingPathComponent:@"realmTest"];
//}

#pragma mark - Core Data Synchronizer

- (RLMRealmConfiguration *)configuration
{
    if (!_configuration) {
        _configuration = [[RLMRealmConfiguration alloc] init];
        _configuration.schemaVersion = 1;
        _configuration.migrationBlock = ^(RLMMigration * _Nonnull migration, uint64_t oldSchemaVersion) {
            if (oldSchemaVersion < 1) {
                // Nothing to do
            }
        };
        _configuration.objectClasses = @[[QSCompany class], [QSEmployee class]];
        // For Extension test (app groups) uncomment below
        /*
         configuration.fileURL = [self realmPath];
         */
    }
    return _configuration;
}

- (QSCloudKitSynchronizer *)synchronizer
{
    if (!_synchronizer) {
        // For Extension test (app groups):
//        _synchronizer = [QSCloudKitSynchronizer cloudKitSynchronizerWithContainerName:@"your-container-name" realmConfiguration:self.realm.configuration suiteName:@"group.com.mentrena.todayextensiontest"];
        
        _synchronizer = [QSCloudKitSynchronizer cloudKitPrivateSynchronizerWithContainerName:@"your-container-name" realmConfiguration:self.configuration];
    }

    return _synchronizer;
}

- (QSCloudKitSynchronizer *)sharedSynchronizer
{
    if (!_sharedSynchronizer) {
        _sharedSynchronizer = [QSCloudKitSynchronizer cloudKitSharedSynchronizerWithContainerName:@"your-container-name" realmConfiguration:self.configuration];
    }
    return _sharedSynchronizer;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
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

@end
