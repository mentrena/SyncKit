//
//  QSMockChangeManager.m
//  QSCloudKitSynchronizer
//
//  Created by Manuel Entrena on 23/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import "QSMockChangeManager.h"
#import <CloudKit/CloudKit.h>
#import "QSObject.h"

@interface QSMockChangeManager ()

@property (nonatomic, strong) NSArray *toUpload;
@property (nonatomic, strong) NSArray *toDelete;

@end

@implementation QSMockChangeManager

- (void)prepareForImport
{
    
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
        [records addObject:[object record]];
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
        [recordIDs addObject:[object recordID]];
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


@end
