//
//  SyncKitCoreDataOSX.h
//  SyncKitCoreDataOSX
//
//  Created by Manuel Entrena on 21/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//! Project version number for SyncKitCoreDataOSX.
FOUNDATION_EXPORT double SyncKitCoreDataOSXVersionNumber;

//! Project version string for SyncKitCoreDataOSX.
FOUNDATION_EXPORT const unsigned char SyncKitCoreDataOSXVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SyncKitCoreDataOSX/PublicHeader.h>

#import <SyncKitCoreData/QSCloudKitSynchronizer.h>
#import <SyncKitCoreData/QSChangeManager.h>
#import <SyncKitCoreData/QSPrimaryKey.h>
#import <SyncKitCoreData/QSCoreDataChangeManager.h>
#import <SyncKitCoreData/QSCloudKitSynchronizer+CoreData.h>
#import <SyncKitCoreData/QSCoreDataStack.h>
#import <SyncKitCoreData/QSEntityIdentifierUpdateMigrationPolicy.h>
#import <SyncKitCoreData/QSManagedObjectContext.h>
