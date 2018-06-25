//
//  SyncKit.h
//  SyncKit
//
//  Created by Manuel Entrena on 19/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for SyncKit.
FOUNDATION_EXPORT double SyncKitVersionNumber;

//! Project version string for SyncKit.
FOUNDATION_EXPORT const unsigned char SyncKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SyncKit/PublicHeader.h>


#import <SyncKit/QSBackupDetection.h>
#import <SyncKit/QSCloudKitSynchronizer.h>
#import <SyncKit/QSCloudKitSynchronizer+Private.h>
#import <SyncKit/QSCloudKitSynchronizer+Realm.h>
#import <SyncKit/QSKeyValueStore.h>
#import <SyncKit/QSModelAdapter.h>
#import <SyncKit/QSPrimaryKey.h>
#import <SyncKit/QSSyncedEntityState.h>
#import <SyncKit/QSTempFileManager.h>
#import <SyncKit/SyncKitLog.h>
#import <SyncKit/QSCloudKitSynchronizer+MultiRealmResultsController.h>
#import <SyncKit/QSCloudKitSynchronizer+Realm.h>
#import <SyncKit/QSMultiRealmResultsController.h>
#import <SyncKit/QSPendingRelationship.h>
#import <SyncKit/QSRealmAdapter.h>
#import <SyncKit/QSRecord.h>
#import <SyncKit/QSServerToken.h>
#import <SyncKit/QSSyncedEntity.h>
