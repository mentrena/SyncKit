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

+ (NSString *)realmPath
{
    return [self realmPathWithAppGroup:nil];
}

+ (NSString *)applicationBackupRealmPathWithSuiteName:(NSString *)suiteName
{
    NSString *rootDirectory;
    if (suiteName) {
        rootDirectory = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:suiteName] path];
    } else {
        rootDirectory = [self applicationDocumentsDirectory];
    }
    return [rootDirectory stringByAppendingPathComponent:@"Realm"];
}

+ (NSString *)applicationDocumentsDirectory
{
#if TARGET_OS_IPHONE
    return [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask,YES) lastObject];
#else
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    return [[[urls lastObject] URLByAppendingPathComponent:@"com.mentrena.QSCloudKitSynchronizer"] path];
#endif
}

+ (NSString *)realmFileName
{
    return @"QSSyncStore.realm";
}

+ (NSString *)realmPathWithAppGroup:(NSString *)suiteName
{
    return [[self applicationBackupRealmPathWithSuiteName:suiteName] stringByAppendingPathComponent:[self realmFileName]];
}

+ (RLMRealmConfiguration *)persistenceConfigurationWithSuiteName:(NSString *)suiteName
{
    RLMRealmConfiguration *configuration = [QSRealmAdapter defaultPersistenceConfiguration];
    configuration.fileURL = [NSURL fileURLWithPath:[self realmPathWithAppGroup:suiteName]];
    return configuration;
}

+ (void)ensurePathAvailableWithSuiteName:(NSString *)suiteName
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:[self applicationBackupRealmPathWithSuiteName:suiteName]]) {
        [fileManager createDirectoryAtPath:[self applicationBackupRealmPathWithSuiteName:suiteName] withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

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
    [self ensurePathAvailableWithSuiteName:suiteName];
    
    QSRealmAdapter *modelAdapter = [[QSRealmAdapter alloc] initWithPersistenceRealmConfiguration:[self persistenceConfigurationWithSuiteName:suiteName] targetRealmConfiguration:targetRealmConfiguration recordZoneID:zoneID];
    NSUserDefaults *suiteUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    CKContainer *container = [CKContainer containerWithIdentifier:containerName];
    QSCloudKitSynchronizer *synchronizer = [[QSCloudKitSynchronizer alloc] initWithIdentifier:@"DefaultRealmPrivateSynchronizer" containerIdentifier:containerName database:container.privateCloudDatabase adapterProvider:nil keyValueStore:suiteUserDefaults];
    [synchronizer addModelAdapter:modelAdapter];
    
    [self transferOldServerChangeTokenTo:modelAdapter userDefaults:suiteUserDefaults container:containerName];
    
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
