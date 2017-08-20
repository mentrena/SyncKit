//
//  QSCloudKitSynchronizer+CoreData.h
//  Pods
//
//  Created by Manuel Entrena on 17/07/2016.
//
//

#import "QSCloudKitSynchronizer.h"
#import "QSCoreDataChangeManager.h"
#import "QSEntityIdentifierUpdateMigrationPolicy.h"

@interface QSCloudKitSynchronizer (CoreData)

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with a Core Data model.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param context       `NSManagedObjectContext` that will be tracked to detect changes and merge new ones.
 *  @param delegate      Delegate implementing `QSCoreDataChangeManager` that will take care of saving the target context when needed.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context changeManagerDelegate:(id<QSCoreDataChangeManagerDelegate>)delegate;

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with a Core Data model.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param context       `NSManagedObjectContext` that will be tracked to detect changes and merge new ones.
 *  @param delegate      Delegate implementing `QSCoreDataChangeManager` that will take care of saving the target context when needed.
 *  @param suiteName    Identifier of shared App Group for the app. This will store the tracking database in the shared container.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context changeManagerDelegate:(id<QSCoreDataChangeManagerDelegate>)delegate suiteName:(NSString *)suiteName;

/**
 *  Creates a migration policy that can be used to perform a migration to a new model that supports the QSPrimaryKey protocol, 
 *  for latest versions of SyncKit. By using this policy for classes that will add support for QSPrimaryKey after the migration we
 *  ensure that existing tracking data will still be valid. Objects will get a value for their primary key as part of the policy.
 *
 *  @return Initialized migration policy.
 */
+ (QSEntityIdentifierUpdateMigrationPolicy *)updateIdentifierMigrationPolicy;

/**
 *  @return File path of database used by SyncKit to keep track of model changes.
 */
+ (NSString *)storePath;

/**
 *  If using app groups, SyncKit offers the option to store its tracking database in the shared container so that it's
 *  accessible by SyncKit from any of the apps in the group. This method returns the path used in this case.
 *
 *  @param  suiteName   Identifier of an App Group this app belongs to.
 *  
 *  @return File path, in the shared container, where SyncKit will store its tracking database.
 */
+ (NSString *)storePathWithAppGroup:(NSString *)suiteName;

@end
