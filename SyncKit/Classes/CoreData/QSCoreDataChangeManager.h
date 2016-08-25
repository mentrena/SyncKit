//
//  QSCoreDataChangeManager.h
//  Pods
//
//  Created by Manuel Entrena on 10/07/2016.
//
//

#import <Foundation/Foundation.h>
#import "QSChangeManager.h"
#import "QSCoreDataStack.h"
#import <CoreData/CoreData.h>
#import <CloudKit/CloudKit.h>

/**
 *  The merge policy to resolve change conflicts. Default value is `QSCloudKitSynchronizerMergePolicyServer`
 */
typedef NS_ENUM(NSInteger, QSCloudKitSynchronizerMergePolicy) {
    /**
     *  Downloaded changes have preference.
     */
    QSCloudKitSynchronizerMergePolicyServer,
    /**
     *  Local changes have preference.
     */
    QSCloudKitSynchronizerMergePolicyClient,
    /**
     *  Delegate can resolve changes manually.
     */
    QSCloudKitSynchronizerMergePolicyCustom
};

@class QSCoreDataChangeManager;

/**
 *  An object implementing `QSCoreDataChangeManagerDelegate` is responsible for saving the target managed object context at the request of the `QSCoreDataChangeManager` in order to persist any downloaded changes.
 */
@protocol QSCoreDataChangeManagerDelegate <NSObject>

/**
 *  Asks the delegate to save the target managed object context before attempting to merge downloaded changes.
 *
 *  @param changeManager The `QSCoreDataChangeManager` requesting the delegate to save.
 *  @param completion    Block to be called once the managed object context has been saved.
 */
- (void)changeManagerRequestsContextSave:(QSCoreDataChangeManager *)changeManager completion:(void(^)(NSError *error))completion;

/**
 *  Tells the delegate to merge downloaded changes into the managed object context. First, the `importContext` must be saved by using `performBlock`. Then, the target managed object context must be saved to persist those changes and the completion block must be called to finalize the synchronization process.
 *
 *  @param changeManager The `QSCoreDataChangeManager` that is providing the changes.
 *  @param importContext `NSManagedObjectContext` containing all downloaded changes. This context has the target context as its parent context.
 *  @param completion    Block to be called once contexts have been saved.
 */
- (void)changeManager:(QSCoreDataChangeManager *)changeManager didImportChanges:(NSManagedObjectContext *)importContext completion:(void(^)(NSError *error))completion;

@optional

/**
 *  Asks the delegate to resolve conflicts for a managed object. The delegate is expected to examine the change dictionary and optionally apply any of those changes to the managed object.
 *
 *  @param changeManager    The `QSCoreDataChangeManager` that is providing the changes.
 *  @param changeDictionary Dictionary containing keys and values with changes for the managed object.
 *  @param object           The `NSManagedObject` that has changed on iCloud.
 */
- (void)changeManager:(QSCoreDataChangeManager *)changeManager gotChanges:(NSDictionary *)changeDictionary forObject:(NSManagedObject *)object;

@end


/**
 *  A `QSCoreDataChangeManager` object implements the `QSChangeManager` protocol to manage changes in a Core Data model.
 */
@interface QSCoreDataChangeManager : NSObject <QSChangeManager>

/**
 *  The `NSManagedObjectModel` used by the change manager to keep track of changes.
 *
 *  @return The model.
 */
+ (NSManagedObjectModel *)persistenceModel;

/**
 *  Initializes a new `QSCoreDataChangeManager`.
 *
 *  @param stack         Core Data stack that will be used by the change manager to persist tracking information.
 *  @param targetContext `NSManagedObjectContext` that will be tracked to detect changes and merge new ones.
 *  @param zoneID        Identifier of the `CKRecordZone` that will contain all data on iCloud.
 *  @param delegate      Delegate that will take care of saving the target context when needed.
 *
 *  @return Initialized core data change manager.
 */
- (instancetype)initWithPersistenceStack:(QSCoreDataStack *)stack targetContext:(NSManagedObjectContext *)targetContext recordZoneID:(CKRecordZoneID *)zoneID delegate:(id<QSCoreDataChangeManagerDelegate>)delegate;

/**
 *  The target context that will be tracked. (read-only)
 */
@property (nonatomic, readonly) NSManagedObjectContext *targetContext;
/**
 *  Delegate. (read-only)
 */
@property (nonatomic, weak, readonly) id<QSCoreDataChangeManagerDelegate> delegate;
/**
 *  Identifier of record zone that will contain data. (read-only)
 */
@property (nonatomic, readonly) CKRecordZoneID *zoneID;
/**
 *  Core Data stack used for tracking information. (read-only)
 */
@property (nonatomic, readonly) QSCoreDataStack *stack;

/**
 *  Merge policy to be used in case of conflicts. Default value is `QSCloudKitSynchronizerMergePolicyServer`
 */
@property (nonatomic, assign) QSCloudKitSynchronizerMergePolicy mergePolicy;


@end
