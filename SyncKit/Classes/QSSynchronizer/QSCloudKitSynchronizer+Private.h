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

+ (CKRecordZoneID *_Nonnull)defaultCustomZoneID;

- (NSString *_Nullable)getStoredDeviceUUID;
- (void)storeDeviceUUID:(NSString *_Nullable)value;
- (CKServerChangeToken *_Nullable)getStoredDatabaseToken;
- (void)storeDatabaseToken:(CKServerChangeToken *_Nullable)token;
- (NSString *_Nullable)storedSubscriptionIDForRecordZoneID:(CKRecordZoneID *_Nonnull)zoneID;
- (NSString *_Nullable)storedDatabaseSubscriptionID;
- (void)storeSubscriptionID:(NSString *_Nonnull)subscriptionID forRecordZoneID:(CKRecordZoneID *_Nonnull)zoneID;
- (void)storeDatabaseSubscriptionID:(NSString *_Nonnull)subscriptionID;
- (void)clearSubscriptionID:(NSString *_Nonnull)subscriptionID;
- (void)clearAllStoredSubscriptionIDs;

@property (nonatomic, readonly, nullable) NSString *deviceIdentifier;
- (void)addMetadataToRecords:(NSArray *_Nonnull)records;

@property (nonatomic, readonly, nonnull) dispatch_queue_t dispatchQueue;

@end
