//
//  QSCloudKitSynchronizer+Realm.m
//  Pods
//
//  Created by Manuel Entrena on 12/05/2017.
//
//

#import "QSCloudKitSynchronizer+Realm.h"
#import "QSCloudKitSynchronizer+Private.h"
#import <SyncKit/SyncKit-Swift.h>

@implementation QSCloudKitSynchronizer (Realm)

+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration
{
    return [QSCloudKitSynchronizer cloudKitPrivateSynchronizerWithContainerName:containerName realmConfiguration:targetRealmConfiguration suiteName:nil recordZoneID:[self defaultCustomZoneID]];
}

+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration suiteName:(NSString *)suiteName
{
    return [QSCloudKitSynchronizer cloudKitPrivateSynchronizerWithContainerName:containerName realmConfiguration:targetRealmConfiguration suiteName:suiteName recordZoneID:[self defaultCustomZoneID]];
}

+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration suiteName:(NSString *)suiteName recordZoneID:(CKRecordZoneID *)zoneID
{
    QSDefaultRealmAdapterProvider *provider = [[QSDefaultRealmAdapterProvider alloc] initWithTargetConfiguration:targetRealmConfiguration zoneID:zoneID appGroup:suiteName];
    NSUserDefaults *suiteUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    CKContainer *container = [CKContainer containerWithIdentifier:containerName];
    QSCloudKitSynchronizer *synchronizer = [[QSCloudKitSynchronizer alloc] initWithIdentifier:@"DefaultRealmPrivateSynchronizer" containerIdentifier:containerName database:container.privateCloudDatabase adapterProvider:provider keyValueStore:suiteUserDefaults];
    [synchronizer addModelAdapter:provider.adapter];
    
    [self transferOldServerChangeTokenTo:provider.adapter userDefaults:suiteUserDefaults container:containerName];
    
    return synchronizer;
}

+ (QSCloudKitSynchronizer *)cloudKitSharedSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration
{
    return [QSCloudKitSynchronizer cloudKitSharedSynchronizerWithContainerName:containerName realmConfiguration:targetRealmConfiguration suiteName:nil];
}

+ (QSCloudKitSynchronizer *)cloudKitSharedSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration suiteName:(NSString *)suiteName
{
    NSUserDefaults *suiteUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    CKContainer *container = [CKContainer containerWithIdentifier:containerName];
    QSDefaultRealmProvider *provider = [[QSDefaultRealmProvider alloc] initWithIdentifier:@"DefaultRealmSharedStackProvider" realmConfiguration:targetRealmConfiguration appGroup:suiteName];
    QSCloudKitSynchronizer *synchronizer = [[QSCloudKitSynchronizer alloc] initWithIdentifier:@"DefaultRealmSharedSynchronizer" containerIdentifier:containerName database:container.sharedCloudDatabase adapterProvider:provider keyValueStore:suiteUserDefaults];
    for (id<QSModelAdapter> modelAdapter in provider.adapterDictionary.allValues) {
        [synchronizer addModelAdapter:modelAdapter];
    }
    
    return synchronizer;
}

+ (void)transferOldServerChangeTokenTo:(id<QSModelAdapter>)adapter userDefaults:(NSUserDefaults *)userDefaults container:(NSString *)container
{
    NSString *key = [container stringByAppendingString:@"QSCloudKitFetchChangesServerTokenKey"];
    NSData *encodedToken = [userDefaults objectForKey:key];
    if (encodedToken) {
        CKServerChangeToken *token = [NSKeyedUnarchiver unarchiveObjectWithData:encodedToken];
        if ([token isKindOfClass:[CKServerChangeToken class]]) {
            [adapter saveToken:token];
        }
        [userDefaults removeObjectForKey:key];
    }
}

@end
