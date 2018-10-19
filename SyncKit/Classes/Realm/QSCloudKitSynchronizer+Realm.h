//
//  QSCloudKitSynchronizer+Realm.h
//  Pods
//
//  Created by Manuel Entrena on 12/05/2017.
//
//

#import "QSCloudKitSynchronizer.h"
#import <Realm/Realm.h>
#import "QSRealmAdapter.h"

@interface QSCloudKitSynchronizer (Realm)

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with a Realm model and the SyncKit default record zone in the private database.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param targetRealmConfiguration Configuration of the Realm that is to be tracked and synchronized.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration;

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with a Realm model and the SyncKit default record zone in the private database.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param targetRealmConfiguration Configuration of the Realm that is to be tracked and synchronized.
 *  @param suiteName    Identifier of shared App Group for the app. This will store the tracking database in the shared container.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration suiteName:(NSString *)suiteName;

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with a Realm model and the SyncKit default record zone in the private database.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param targetRealmConfiguration Configuration of the Realm that is to be tracked and synchronized.
 *  @param suiteName    Identifier of shared App Group for the app. This will store the tracking database in the shared container.
 *  @param zoneID       CKRecordZoneID in the private database that will be used by the synchronizer.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration suiteName:(NSString *)suiteName recordZoneID:(CKRecordZoneID *)zoneID;

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with a Realm model and the shared database.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param targetRealmConfiguration Configuration of the Realm that is to be tracked and synchronized.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitSharedSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration;

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with a Realm model and the shared database.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param targetRealmConfiguration Configuration of the Realm that is to be tracked and synchronized.
 *  @param suiteName    Identifier of shared App Group for the app. This will store the tracking database in the shared container.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitSharedSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration suiteName:(NSString *)suiteName;

/**
 *  @return File path of database used by SyncKit to keep track of model changes.
 */
+ (NSString *)realmPath;

/**
 *  If using app groups, SyncKit offers the option to store its tracking database in the shared container so that it's
 *  accessible by SyncKit from any of the apps in the group. This method returns the path used in this case.
 *
 *  @param  suiteName   Identifier of an App Group this app belongs to.
 *
 *  @return File path, in the shared container, where SyncKit will store its tracking database.
 */
+ (NSString *)realmPathWithAppGroup:(NSString *)suiteName;

@end
