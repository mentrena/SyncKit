//
//  QSCloudKitSynchronizer+Private.m
//  SyncKitCoreData
//
//  Created by Manuel Entrena on 02/12/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import "QSCloudKitSynchronizer+Private.h"

static NSString * const QSCloudKitCustomZoneName = @"QSCloudKitCustomZoneName";

static NSString * const QSCloudKitStoredDeviceUUIDKey = @"QSCloudKitStoredDeviceUUIDKey";
static NSString * const QSSubscriptionIdentifierKey = @"QSSubscriptionIdentifierKey";
static NSString * const QSDatabaseServerChangeTokenKey = @"QSDatabaseServerChangeTokenKey";

@implementation QSCloudKitSynchronizer (Private)

@dynamic dispatchQueue;
@dynamic deviceIdentifier;

+ (CKRecordZoneID *)defaultCustomZoneID
{
    return [[CKRecordZoneID alloc] initWithZoneName:QSCloudKitCustomZoneName ownerName:CKCurrentUserDefaultName];
}

- (NSString *)userDefaultsKeyForKey:(NSString *)key
{
    return [NSString stringWithFormat:@"%@-%@-%@", self.containerIdentifier, self.identifier, key];
}

- (NSString *)storeKeyForZoneID:(CKRecordZoneID *)zoneID
{
    return [self userDefaultsKeyForKey:[NSString stringWithFormat:@"%@.%@", zoneID.ownerName, zoneID.zoneName]];
}

- (NSString *)storeKeyForDatabase:(CKDatabase *)database
{
    return [self userDefaultsKeyForKey:database.databaseScope == CKDatabaseScopePrivate ? @"privateDatabase" : @"sharedDatabase"];
}

- (NSString *)getStoredDeviceUUID
{
    return (NSString *)[self.keyValueStore objectForKey:[self userDefaultsKeyForKey:QSCloudKitStoredDeviceUUIDKey]];
}

- (void)storeDeviceUUID:(NSString *)value
{
    NSString *key = [self userDefaultsKeyForKey:QSCloudKitStoredDeviceUUIDKey];
    if (value) {
        [self.keyValueStore setObject:value forKey:key];
    } else {
        [self.keyValueStore removeObjectForKey:key];
    }
}

- (CKServerChangeToken *)getStoredDatabaseToken
{
    NSData *encodedToken = (NSData *)[self.keyValueStore objectForKey:[self userDefaultsKeyForKey:QSDatabaseServerChangeTokenKey]];
    return encodedToken ? [NSKeyedUnarchiver unarchiveObjectWithData:encodedToken] : nil;
}

- (void)storeDatabaseToken:(CKServerChangeToken *)token
{
    NSString *key = [self userDefaultsKeyForKey:QSDatabaseServerChangeTokenKey];
    
    if (token) {
        NSData *encodedToken = [NSKeyedArchiver archivedDataWithRootObject:token];

        [self.keyValueStore setObject:encodedToken forKey:key];
    } else {
        [self.keyValueStore removeObjectForKey:key];
    }
}

- (NSString *)storedSubscriptionIDForRecordZoneID:(CKRecordZoneID *)zoneID
{
    NSDictionary *subscriptionIDsDictionary = [self getStoredSubscriptionIDsDictionary];
    return subscriptionIDsDictionary[[self storeKeyForZoneID:zoneID]];
}

- (NSString *_Nullable)storedDatabaseSubscriptionID
{
    NSDictionary *subscriptionIDsDictionary = [self getStoredSubscriptionIDsDictionary];
    return subscriptionIDsDictionary[[self storeKeyForDatabase:self.database]];
}

- (void)storeSubscriptionID:(NSString *)subscriptionID forRecordZoneID:(CKRecordZoneID *)zoneID
{
    NSMutableDictionary *subscriptionIDsDictionary = [[self getStoredSubscriptionIDsDictionary] mutableCopy];
    if (!subscriptionIDsDictionary) {
        subscriptionIDsDictionary = [NSMutableDictionary dictionary];
    }
    subscriptionIDsDictionary[[self storeKeyForZoneID:zoneID]] = subscriptionID;
    [self setStoredSubscriptionIDsDictionary:subscriptionIDsDictionary];
}

- (void)storeDatabaseSubscriptionID:(NSString *_Nonnull)subscriptionID
{
    NSMutableDictionary *subscriptionIDsDictionary = [[self getStoredSubscriptionIDsDictionary] mutableCopy];
    if (!subscriptionIDsDictionary) {
        subscriptionIDsDictionary = [NSMutableDictionary dictionary];
    }
    subscriptionIDsDictionary[[self storeKeyForDatabase:self.database]] = subscriptionID;
    [self setStoredSubscriptionIDsDictionary:subscriptionIDsDictionary];
}

- (void)clearSubscriptionID:(NSString *)subscriptionID
{
    NSMutableDictionary *subscriptionIDsDictionary = [[self getStoredSubscriptionIDsDictionary] mutableCopy];
    NSMutableDictionary *newDictionary = [NSMutableDictionary dictionary];
    [subscriptionIDsDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull key, NSString *  _Nonnull identifier, BOOL * _Nonnull stop) {
        if (![identifier isEqualToString:subscriptionID]) {
            newDictionary[key] = identifier;
        }
    }];
    [self setStoredSubscriptionIDsDictionary:newDictionary];
}

- (NSDictionary *)getStoredSubscriptionIDsDictionary
{
    return [self.keyValueStore objectForKey:[self userDefaultsKeyForKey:QSSubscriptionIdentifierKey]];
}

- (void)setStoredSubscriptionIDsDictionary:(NSDictionary *)dictionary
{
    NSString *key = [self userDefaultsKeyForKey:QSSubscriptionIdentifierKey];
    if (dictionary) {
        [self.keyValueStore setObject:dictionary forKey:key];
    } else {
        [self.keyValueStore removeObjectForKey:key];
    }
}

- (void)clearAllStoredSubscriptionIDs
{
    [self setStoredSubscriptionIDsDictionary:nil];
}

- (void)addMetadataToRecords:(NSArray *)records
{
    for (CKRecord *record in records) {
        record[QSCloudKitDeviceUUIDKey] = self.deviceIdentifier;
        if (self.compatibilityVersion > 0) {
            record[QSCloudKitModelCompatibilityVersionKey] = @(self.compatibilityVersion);
        }
    }
}

@end
