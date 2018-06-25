//
//  QSCloudKitSynchronizer+Private.h
//  SyncKitCoreData
//
//  Created by Manuel Entrena on 02/12/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import "QSCloudKitSynchronizer.h"
#import <CloudKit/CloudKit.h>

FOUNDATION_EXPORT NSString * _Nonnull const QSCloudKitDeviceUUIDKey;
FOUNDATION_EXPORT NSString * _Nonnull const QSCloudKitModelCompatibilityVersionKey;

@interface QSCloudKitSynchronizer (Private)

+ (CKRecordZoneID *)defaultCustomZoneID;

- (NSString *)getStoredDeviceUUID;
- (void)storeDeviceUUID:(NSString *)value;
- (CKServerChangeToken *)getStoredDatabaseToken;
- (void)storeDatabaseToken:(CKServerChangeToken *)token;
- (NSString *)storedSubscriptionIDForRecordZoneID:(CKRecordZoneID *)zoneID;
- (void)storeSubscriptionID:(NSString *)subscriptionID forRecordZoneID:(CKRecordZoneID *)zoneID;
- (void)clearSubscriptionID:(NSString *)subscriptionID;
- (void)clearAllStoredSubscriptionIDs;

@property (nonatomic, readonly) NSString *deviceIdentifier;
- (void)addMetadataToRecords:(NSArray *)records;

@property (nonatomic, readonly) dispatch_queue_t dispatchQueue;

@end
