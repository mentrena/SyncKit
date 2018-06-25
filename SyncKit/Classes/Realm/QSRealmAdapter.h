//
//  QSRealmAdapter.h
//  Pods
//
//  Created by Manuel Entrena on 05/05/2017.
//
//

#import <Foundation/Foundation.h>
#import "QSModelAdapter.h"
#import <CloudKit/CloudKit.h>

@class RLMRealmConfiguration;
@class RLMObject;
@class QSRealmAdapter;

@protocol QSRealmAdapterDelegate <NSObject>

/**
 *  Asks the delegate to resolve conflicts for a managed object. The delegate is expected to examine the change dictionary and optionally apply any of those changes to the managed object.
 *
 *  @param adapter    The `QSRealmAdapter` that is providing the changes.
 *  @param changeDictionary Dictionary containing keys and values with changes for the managed object. Values can be [NSNull null] to represent a nil value.
 *  @param object           The `RLMObject` that has changed on iCloud.
 */
- (void)realmAdapter:(QSRealmAdapter *_Nonnull)adapter gotChanges:(NSDictionary *_Nonnull)changeDictionary forObject:(RLMObject *_Nonnull)object;

@end

@interface QSRealmAdapter : NSObject <QSModelAdapter>

/**
 *  Initializes a new `QSRealmAdapter`.
 *
 *  @param configuration            Realm configuration for the realm used to track changes
 *  @param targetRealmConfiguration Realm configuration of the realm to track and synchronize
 *  @param zoneID                   Identifier of the `CKRecordZone` that will contain all data on iCloud.
 *
 *  @return Initialized Realm change manager.
 */
- (instancetype _Nonnull )initWithPersistenceRealmConfiguration:(RLMRealmConfiguration *_Nonnull)configuration targetRealmConfiguration:(RLMRealmConfiguration *_Nonnull)targetRealmConfiguration recordZoneID:(CKRecordZoneID *_Nonnull)zoneID;

/**
 *  Configuration of the Realm used for tracking. (read-only)
 */
@property (nonatomic, strong, readonly) RLMRealmConfiguration * _Nonnull persistenceConfiguration;
/**
 *  Configuration of the target realm that will be tracked. (read-only)
 */
@property (nonatomic, strong, readonly) RLMRealmConfiguration * _Nonnull targetConfiguration;

/**
 *  Identifier of record zone that will contain data. (read-only)
 */
@property (nonatomic, strong, readonly) CKRecordZoneID * _Nonnull recordZoneID;
/**
 *  Delegate. (read-only)
 */
@property (nonatomic, weak) id<QSRealmAdapterDelegate> _Nullable  delegate;
/**
 *  Merge policy to be used in case of conflicts. Default value is `QSModelAdapterMergePolicyServer`
 */
@property (nonatomic, assign) QSModelAdapterMergePolicy mergePolicy;

/**
 *  If this is true data fields will be uploaded as data, instead of using CKAsset properties on the records.
 */
@property (nonatomic, assign) BOOL forceDataTypeInsteadOfAsset;

+ (nonnull RLMRealmConfiguration *)defaultPersistenceConfiguration;

@end
