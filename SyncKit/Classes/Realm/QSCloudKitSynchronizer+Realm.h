//
//  QSCloudKitSynchronizer+Realm.h
//  Pods
//
//  Created by Manuel Entrena on 12/05/2017.
//
//

#import "QSCloudKitSynchronizer.h"
#import <Realm/Realm.h>
#import "QSRealmChangeManager.h"

@interface QSCloudKitSynchronizer (Realm)

/**
 *  Creates a new `QSCloudKitSynchronizer` prepared to work with a Realm model.
 *
 *  @param containerName Identifier of the iCloud container to be used. The application must have the right entitlements to be able to access this container.
 *  @param targetRealmConfiguration Configuration of the Realm that is to be tracked and synchronized.
 *
 *  @return Initialized synchronizer.
 */
+ (QSCloudKitSynchronizer *)cloudKitSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration;

@end
