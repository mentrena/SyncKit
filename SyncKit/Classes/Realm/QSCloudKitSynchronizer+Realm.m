//
//  QSCloudKitSynchronizer+Realm.m
//  Pods
//
//  Created by Manuel Entrena on 12/05/2017.
//
//

#import "QSCloudKitSynchronizer+Realm.h"

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
    RLMRealmConfiguration *configuration = [QSRealmChangeManager defaultPersistenceConfiguration];
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

+ (CKRecordZoneID *)defaultCustomZoneID
{
    return [[CKRecordZoneID alloc] initWithZoneName:@"QSCloudKitCustomZoneName" ownerName:CKOwnerDefaultName];
}

+ (QSCloudKitSynchronizer *)cloudKitSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration
{
    return [QSCloudKitSynchronizer cloudKitSynchronizerWithContainerName:containerName realmConfiguration:targetRealmConfiguration suiteName:nil];
}

+ (QSCloudKitSynchronizer *)cloudKitSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration suiteName:(NSString *)suiteName
{
    [self ensurePathAvailableWithSuiteName:suiteName];
    QSRealmChangeManager *changeManager = [[QSRealmChangeManager alloc] initWithPersistenceRealmConfiguration:[self persistenceConfigurationWithSuiteName:suiteName] targetRealmConfiguration:targetRealmConfiguration recordZoneID:[self defaultCustomZoneID]];
    QSCloudKitSynchronizer *synchronizer = [[QSCloudKitSynchronizer alloc] initWithContainerIdentifier:containerName recordZoneID:[self defaultCustomZoneID] changeManager:changeManager suiteName:suiteName];
    return synchronizer;
}

@end
