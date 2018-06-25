//
//  QSMockModelAdapter.m
//  QSCloudKitSynchronizer
//
//  Created by Manuel Entrena on 23/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import "QSMockModelAdapter.h"
#import <CloudKit/CloudKit.h>
#import "QSObject.h"

@interface QSMockModelAdapter ()

@property (nonatomic, strong) NSArray *toUpload;
@property (nonatomic, strong) NSArray *toDelete;
@property (nonatomic, strong) CKServerChangeToken *token;

@end

@implementation QSMockModelAdapter

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.sharesByIdentifier = [NSMutableDictionary dictionary];
        self.recordsByIdentifier = [NSMutableDictionary dictionary];
        self.deleteChangeTrackingCalled = NO;
    }
    return self;
}

- (void)prepareForImport
{
    
}

- (BOOL)hasChanges
{
    return self.toUpload.count + self.toDelete.count > 0;
}

- (void)saveChangesInRecords:(NSArray<CKRecord *> *)records
{
    for (CKRecord *record in records) {
        [self saveChangesInRecord:record];
    }
}

- (void)saveChangesInRecord:(CKRecord *)record
{
    BOOL assigned = NO;
    for (QSObject *object in self.objects) {
        if ([object.identifier isEqualToString:record.recordID.recordName]) {
            [object saveRecord:record];
            assigned = YES;
            break;
        }
    }
    
    if (!assigned) {
        QSObject *object = [[QSObject alloc] initWithRecord:record];
        self.objects = [self.objects arrayByAddingObject:object];
    }
}

- (void)deleteRecordsWithIDs:(NSArray<CKRecordID *> *)recordIDs
{
    for (CKRecordID *recordID in recordIDs) {
        [self deleteRecordWithID:recordID];
    }
}

- (void)deleteRecordWithID:(CKRecordID *)recordID
{
    QSObject *objectToRemove = nil;
    for (QSObject *object in self.objects) {
        if ([object.identifier isEqualToString:recordID.recordName]) {
            objectToRemove = object;
            break;
        }
    }
    if (objectToRemove) {
        NSMutableArray *mutable = [self.objects mutableCopy];
        [mutable removeObject:objectToRemove];
        self.objects = [mutable copy];
    }
}

- (NSArray *)recordsToUploadWithLimit:(NSInteger)limit
{
    NSMutableArray *records = [NSMutableArray array];
    for (QSObject *object in self.toUpload) {
        if (records.count >= limit) {
            break;
        }
        [records addObject:[object recordWithZoneID:self.recordZoneID]];
    }
    return [records copy];
}

- (void)didUploadRecords:(NSArray *)savedRecords
{
    NSMutableArray *toUpload2 = [self.toUpload mutableCopy];
    for (CKRecord *record in savedRecords) {
        for (QSObject *object in self.toUpload) {
            if ([object.identifier isEqualToString:record.recordID.recordName]) {
                [toUpload2 removeObject:object];
            }
        }
    }
    self.toUpload = [toUpload2 copy];
}

- (NSArray *)recordIDsMarkedForDeletionWithLimit:(NSInteger)limit
{
    NSMutableArray *recordIDs = [NSMutableArray array];
    for (QSObject *object in self.toDelete) {
        if (recordIDs.count >= limit) {
            break;
        }
        [recordIDs addObject:[object recordIDWithZoneID:self.recordZoneID]];
    }
    return [recordIDs copy];
}

- (void)didDeleteRecordIDs:(NSArray *)deletedRecordIDs
{
    for (CKRecordID *recordID in deletedRecordIDs) {
        [self deleteRecordWithID:recordID];
    }
}

- (BOOL)hasRecordID:(CKRecordID *)recordID
{
    for (QSObject *object in self.objects) {
        if ([object.identifier isEqualToString:recordID.recordName]) {
            return YES;
        }
    }
    return NO;
}

- (void)persistImportedChangesWithCompletion:(void(^)(NSError *error))completion
{
    completion(nil);
}

- (void)didFinishImportWithError:(NSError *)error
{
    self.toDelete = nil;
    self.toUpload = nil;
}

- (void)deleteChangeTracking
{
    self.deleteChangeTrackingCalled = YES;
    self.objects = nil;
    self.toDelete = nil;
    self.toUpload = nil;
}

- (void)markForUpload:(NSArray *)objects
{
    self.toUpload = objects;
}

- (void)markForDeletion:(NSArray *)objects
{
    self.toDelete = objects;
}

- (nullable CKRecord *)recordForObjectWithIdentifier:(nonnull NSString *)objectIdentifier
{
    return self.recordsByIdentifier[objectIdentifier];
}

- (nullable CKShare *)shareForObjectWithIdentifier:(nonnull NSString *)objectIdentifier
{
    return self.sharesByIdentifier[objectIdentifier];
}

- (void)saveShare:(nonnull CKShare *)share forObjectWithIdentifier:(nonnull NSString *)objectIdentifier
{
    self.sharesByIdentifier[objectIdentifier] = share;
}

- (void)deleteShareForObjectWithIdentifier:(nonnull NSString *)objectIdentifier
{
    [self.sharesByIdentifier removeObjectForKey:objectIdentifier];
}

- (nonnull CKRecordZoneID *)recordZoneID
{
    return self.recordZoneIDValue;
}

- (nullable CKServerChangeToken *)serverChangeToken
{
    return self.token;
}

- (void)saveToken:(nullable CKServerChangeToken *)token
{
    self.token = token;
}

- (void)deleteShareForObject:(id)object {
    
}


- (nullable CKRecord *)recordForObject:(id)object {
    return nil;
}


- (void)saveShare:(nonnull CKShare *)share forObject:(id)object {
    
}


- (nullable CKShare *)shareForObject:(id)object {
    return nil;
}


@end
