//
//  QSCloudKitSynchronizer+Private.m
//  SyncKitCoreData
//
//  Created by Manuel Entrena on 02/12/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import "QSCloudKitSynchronizer+Private.h"

static NSString * const QSCloudKitCustomZoneName = @"QSCloudKitCustomZoneName";

@implementation QSCloudKitSynchronizer (Private)

+ (CKRecordZoneID *)defaultCustomZoneID
{
    if (@available(iOS 10.0, macOS 10.12, watchOS 3.0, *)) {
        return [[CKRecordZoneID alloc] initWithZoneName:QSCloudKitCustomZoneName ownerName:CKCurrentUserDefaultName];
    } else {
        return [[CKRecordZoneID alloc] initWithZoneName:QSCloudKitCustomZoneName ownerName:CKOwnerDefaultName];
    }
}

@end
