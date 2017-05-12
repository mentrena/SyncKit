//
//  QSRealmChangeManager.h
//  Pods
//
//  Created by Manuel Entrena on 05/05/2017.
//
//

#import <Foundation/Foundation.h>
#import "QSChangeManager.h"
#import <CloudKit/CloudKit.h>

@class RLMRealmConfiguration;
@class RLMObject;
@class QSRealmChangeManager;

@protocol QSRealmChangeManagerDelegate <NSObject>

/**
 *  Asks the delegate to resolve conflicts for a managed object. The delegate is expected to examine the change dictionary and optionally apply any of those changes to the managed object.
 *
 *  @param changeManager    The `QSRealmChangeManager` that is providing the changes.
 *  @param changeDictionary Dictionary containing keys and values with changes for the managed object.
 *  @param object           The `RLMObject` that has changed on iCloud.
 */
- (void)changeManager:(QSRealmChangeManager *)changeManager gotChanges:(NSDictionary *)changeDictionary forObject:(RLMObject *)object;

@end

@interface QSRealmChangeManager : NSObject <QSChangeManager>

/**
 *  Initializes a new `QSRealmChangeManager`.
 *
 *  @param configuration            Realm configuration for the realm used to track changes
 *  @param targetRealmConfiguration Realm configuration of the realm to track and synchronize
 *  @param zoneID                   Identifier of the `CKRecordZone` that will contain all data on iCloud.
 *
 *  @return Initialized Realm change manager.
 */
- (instancetype)initWithPersistenceRealmConfiguration:(RLMRealmConfiguration *)configuration targetRealmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration recordZoneID:(CKRecordZoneID *)zoneID;

/**
 *  Configuration of the Realm used for tracking. (read-only)
 */
@property (nonatomic, strong, readonly) RLMRealmConfiguration *persistenceConfiguration;
/**
 *  Configuration of the target realm that will be tracked. (read-only)
 */
@property (nonatomic, strong, readonly) RLMRealmConfiguration *targetConfiguration;

/**
 *  Identifier of record zone that will contain data. (read-only)
 */
@property (nonatomic, strong, readonly) CKRecordZoneID *recordZoneID;
/**
 *  Delegate. (read-only)
 */
@property (nonatomic, weak) id<QSRealmChangeManagerDelegate> delegate;
/**
 *  Merge policy to be used in case of conflicts. Default value is `QSCloudKitSynchronizerMergePolicyServer`
 */
@property (nonatomic, assign) QSCloudKitSynchronizerMergePolicy mergePolicy;

+ (RLMRealmConfiguration *)defaultPersistenceConfiguration;

@end
