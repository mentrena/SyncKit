//
//  SyncKit.h
//  SyncKit
//
//  Created by Manuel Entrena on 19/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//
#import <Foundation/Foundation.h>

//! Project version number for SyncKit.
FOUNDATION_EXPORT double SyncKitVersionNumber;

//! Project version string for SyncKit.
FOUNDATION_EXPORT const unsigned char SyncKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SyncKit/PublicHeader.h>


#import <SyncKit/QSBackupDetection.h>
#import <SyncKit/QSCloudKitSynchronizer.h>
#import <SyncKit/QSCloudKitSynchronizer+Private.h>
#import <SyncKit/QSKeyValueStore.h>
#import <SyncKit/QSModelAdapter.h>
#import <SyncKit/QSPrimaryKey.h>
#import <SyncKit/QSSyncedEntityState.h>
#import <SyncKit/QSTempFileManager.h>
#import <SyncKit/SyncKitLog.h>
#import <SyncKit/NSManagedObjectContext+QSFetch.h>
#import <SyncKit/QSCloudKitSynchronizer+CoreData.h>
#import <SyncKit/QSCloudKitSynchronizer+MultiFetchedResultsController.h>
#import <SyncKit/QSCoreDataAdapter.h>
#import <SyncKit/QSCoreDataMultiFetchedResultsController.h>
#import <SyncKit/QSCoreDataStack.h>
#import <SyncKit/QSDefaultCoreDataAdapterDelegate.h>
#import <SyncKit/QSDefaultCoreDataStackProvider.h>
#import <SyncKit/QSEntityIdentifierUpdateMigrationPolicy.h>
#import <SyncKit/QSManagedObjectContext.h>
#import <SyncKit/QSPendingRelationship+CoreDataClass.h>
#import <SyncKit/QSPendingRelationship+CoreDataProperties.h>
#import <SyncKit/QSRecord+CoreDataClass.h>
#import <SyncKit/QSRecord+CoreDataProperties.h>
#import <SyncKit/QSServerToken+CoreDataClass.h>
#import <SyncKit/QSServerToken+CoreDataProperties.h>
#import <SyncKit/QSSyncedEntity+CoreDataClass.h>
#import <SyncKit/QSSyncedEntity+CoreDataProperties.h>
