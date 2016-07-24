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

@interface QSObject : NSObject

@property (nonatomic, strong) NSNumber *number;
@property (nonatomic, strong) NSString *identifier;

- (CKRecord *)record;
- (CKRecordID *)recordID;

- (instancetype)initWithIdentifier:(NSString *)identifier number:(NSNumber *)number;
- (instancetype)initWithRecord:(CKRecord *)record;

- (void)saveRecord:(CKRecord *)record;

@end
