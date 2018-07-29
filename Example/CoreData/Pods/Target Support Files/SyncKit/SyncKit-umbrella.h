#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "QSBackupDetection.h"
#import "QSCloudKitSynchronizer+Private.h"
#import "QSCloudKitSynchronizer.h"
#import "QSKeyValueStore.h"
#import "QSModelAdapter.h"
#import "QSPrimaryKey.h"
#import "QSSyncedEntityState.h"
#import "QSTempFileManager.h"
#import "SyncKit.h"
#import "SyncKitLog.h"
#import "NSManagedObjectContext+QSFetch.h"
#import "QSCloudKitSynchronizer+CoreData.h"
#import "QSCloudKitSynchronizer+MultiFetchedResultsController.h"
#import "QSCoreDataAdapter.h"
#import "QSCoreDataMultiFetchedResultsController.h"
#import "QSCoreDataStack.h"
#import "QSDefaultCoreDataAdapterDelegate.h"
#import "QSDefaultCoreDataStackProvider.h"
#import "QSEntityIdentifierUpdateMigrationPolicy.h"
#import "QSManagedObjectContext.h"
#import "QSPendingRelationship+CoreDataClass.h"
#import "QSPendingRelationship+CoreDataProperties.h"
#import "QSRecord+CoreDataClass.h"
#import "QSRecord+CoreDataProperties.h"
#import "QSServerToken+CoreDataClass.h"
#import "QSServerToken+CoreDataProperties.h"
#import "QSSyncedEntity+CoreDataClass.h"
#import "QSSyncedEntity+CoreDataProperties.h"

FOUNDATION_EXPORT double SyncKitVersionNumber;
FOUNDATION_EXPORT const unsigned char SyncKitVersionString[];

