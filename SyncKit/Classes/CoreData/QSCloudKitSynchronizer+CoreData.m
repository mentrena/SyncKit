//
//  QSCloudKitSynchronizer+CoreData.m
//  Pods
//
//  Created by Manuel Entrena on 17/07/2016.
//
//

#import "QSCloudKitSynchronizer+CoreData.h"
#import "QSCloudKitSynchronizer+Private.h"
#import "QSDefaultCoreDataStackProvider.h"
#import "QSDefaultCoreDataAdapterDelegate.h"
#import <SyncKit/SyncKit-Swift.h>

@implementation QSCloudKitSynchronizer (CoreData)

+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context
{
    return [self cloudKitPrivateSynchronizerWithContainerName:containerName managedObjectContext:context suiteName:nil recordZoneID:[self defaultCustomZoneID]];
}

+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context suiteName:(NSString *)suiteName
{
    return [self cloudKitPrivateSynchronizerWithContainerName:containerName managedObjectContext:context suiteName:suiteName recordZoneID:[self defaultCustomZoneID]];
}

+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context suiteName:(NSString *)suiteName recordZoneID:(CKRecordZoneID *)zoneID
{
    QSDefaultCoreDataAdapterProvider *adapterProvider = [[QSDefaultCoreDataAdapterProvider alloc] initWithManagedObjectContext:context zoneID:zoneID appGroup:suiteName];
    NSUserDefaults *suiteUserDefaults = suiteName ? [[NSUserDefaults alloc] initWithSuiteName:suiteName] : [NSUserDefaults standardUserDefaults];
    CKContainer *container = [CKContainer containerWithIdentifier:containerName];
    QSCloudKitSynchronizer *synchronizer = [[QSCloudKitSynchronizer alloc] initWithIdentifier:@"DefaultCoreDataPrivateSynchronizer" containerIdentifier:containerName database:container.privateCloudDatabase adapterProvider:adapterProvider keyValueStore:suiteUserDefaults];
    QSCoreDataAdapter *adapter = adapterProvider.adapter;
    [synchronizer addModelAdapter:adapter];
    
    [self transferOldServerChangeTokenTo:adapter userDefaults:suiteUserDefaults container:containerName];
    
    return synchronizer;
}

+ (QSCloudKitSynchronizer *)cloudKitSharedSynchronizerWithContainerName:(NSString *)containerName objectModel:(NSManagedObjectModel *)model
{
    return [self cloudKitSharedSynchronizerWithContainerName:containerName objectModel:model suiteName:nil];
}

+ (QSCloudKitSynchronizer *)cloudKitSharedSynchronizerWithContainerName:(NSString *)containerName objectModel:(NSManagedObjectModel *)model suiteName:(NSString *)suiteName
{
    QSDefaultCoreDataStackProvider *provider = [[QSDefaultCoreDataStackProvider alloc] initWithIdentifier:@"DefaultCoreDataSharedStackProvider" storeType:NSSQLiteStoreType model:model appGroup:suiteName];
    NSUserDefaults *suiteUserDefaults = suiteName ? [[NSUserDefaults alloc] initWithSuiteName:suiteName] : [NSUserDefaults standardUserDefaults];
    CKContainer *container = [CKContainer containerWithIdentifier:containerName];
    QSCloudKitSynchronizer *synchronizer = [[QSCloudKitSynchronizer alloc] initWithIdentifier:@"DefaultCoreDataSharedSynchronizer" containerIdentifier:containerName database:container.sharedCloudDatabase adapterProvider:provider keyValueStore:suiteUserDefaults];
    for (id<QSModelAdapter> adapter in provider.adapterDictionary.allValues) {
        [synchronizer addModelAdapter:adapter];
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

+ (NSEntityMigrationPolicy *)updateIdentifierMigrationPolicy
{
    NSString *storePath = [QSDefaultCoreDataAdapterProvider storePathWithAppGroup:nil];
    if ([QSEntityIdentifierUpdateMigrationPolicy stack] == nil && [[NSFileManager defaultManager] fileExistsAtPath:storePath]) {
        QSCoreDataStack *stack = [[QSCoreDataStack alloc] initWithStoreType:NSSQLiteStoreType model:[QSCoreDataAdapter persistenceModel] storePath:storePath];
        [QSEntityIdentifierUpdateMigrationPolicy setCoreDataStack:stack];
    }
    return [[QSEntityIdentifierUpdateMigrationPolicy alloc] init];
}

@end
