//
//  QSObject.h
//  QSCloudKitSynchronizer
//
//  Created by Manuel Entrena on 24/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import <Foundation/Foundation.h>
@class CKRecord;
@class CKRecordID;
@class CKRecordZoneID;

@interface QSObject : NSObject

@property (nonatomic, strong) NSNumber *number;
@property (nonatomic, strong) NSString *identifier;

- (CKRecord *)recordWithZoneID:(CKRecordZoneID *)zoneID;
- (CKRecordID *)recordIDWithZoneID:(CKRecordZoneID *)zoneID;

- (instancetype)initWithIdentifier:(NSString *)identifier number:(NSNumber *)number;
- (instancetype)initWithRecord:(CKRecord *)record;

- (void)saveRecord:(CKRecord *)record;

@end
