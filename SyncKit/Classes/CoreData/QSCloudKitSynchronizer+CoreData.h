//
//  QSCloudKitSynchronizer+CoreData.h
//  Pods
//
//  Created by Manuel Entrena on 17/07/2016.
//
//

#import "QSCloudKitSynchronizer.h"
#import "QSCoreDataAdapter.h"
#import "QSEntityIdentifierUpdateMigrationPolicy.h"

@interface QSCloudKitSynchronizer (CoreData)

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with the given Core Data model and the default SyncKit record zone in the private database.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param context       `NSManagedObjectContext` that will be tracked to detect changes and merge new ones.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context;

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with the given Core Data model and the default SyncKit record zone in the private database.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param context       `NSManagedObjectContext` that will be tracked to detect changes and merge new ones.
 *  @param suiteName    Identifier of shared App Group for the app. This will store the tracking database in the shared container.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context suiteName:(NSString *)suiteName;

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with the given Core Data model and the default SyncKit record zone in the private database.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param context       `NSManagedObjectContext` that will be tracked to detect changes and merge new ones.
 *  @param suiteName    Identifier of shared App Group for the app. This will store the tracking database in the shared container.
 *  @param zoneID       CKRecordZoneID in the private database that will be used by the synchronizer.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context suiteName:(NSString *)suiteName recordZoneID:(CKRecordZoneID *)zoneID;

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with the given Core Data model and the CloudKit shared database.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param model  `NSManagedObjectModel`
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitSharedSynchronizerWithContainerName:(NSString *)containerName objectModel:(NSManagedObjectModel *)model;

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with the given Core Data model and the CloudKit shared database.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param model  `NSManagedObjectModel`
 *  @param suiteName    Identifier of shared App Group for the app. This will store the tracking database in the shared container.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitSharedSynchronizerWithContainerName:(NSString *)containerName objectModel:(NSManagedObjectModel *)model suiteName:(NSString *)suiteName;

/**
 *  Creates a migration policy that can be used to perform a migration to a new model that supports the QSPrimaryKey protocol, 
 *  for latest versions of SyncKit. By using this policy for classes that will add support for QSPrimaryKey after the migration we
 *  ensure that existing tracking data will still be valid. Objects will get a value for their primary key as part of the policy.
 *
 *  @return Initialized migration policy.
 */
+ (QSEntityIdentifierUpdateMigrationPolicy *)updateIdentifierMigrationPolicy;


@end
