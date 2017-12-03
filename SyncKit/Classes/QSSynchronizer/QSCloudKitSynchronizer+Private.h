//
//  QSCloudKitSynchronizer+Private.h
//  SyncKitCoreData
//
//  Created by Manuel Entrena on 02/12/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import "QSCloudKitSynchronizer.h"
#import <CloudKit/CloudKit.h>

@interface QSCloudKitSynchronizer (Private)

+ (CKRecordZoneID *)defaultCustomZoneID;

@end
