//
//  QSObject.m
//  QSCloudKitSynchronizer
//
//  Created by Manuel Entrena on 24/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import "QSObject.h"
#import <CloudKit/CloudKit.h>

@implementation QSObject

- (instancetype)initWithIdentifier:(NSString *)identifier number:(NSNumber *)number
{
    self = [super init];
    if (self) {
        self.identifier = identifier;
        self.number = number;
    }
    return self;
}

- (instancetype)initWithRecord:(CKRecord *)record
{
    return [self initWithIdentifier:record.recordID.recordName number:record[@"number"]];
}

- (CKRecord *)record
{
    CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName:self.identifier];
    CKRecord *record = [[CKRecord alloc] initWithRecordType:@"object" recordID:recordID];
    record[@"number"] = self.number;
    return record;
}

- (CKRecordID *)recordID
{
    return [[CKRecordID alloc] initWithRecordName:self.identifier];
}

- (void)saveRecord:(CKRecord *)record
{
    self.number = record[@"number"];
}

@end
