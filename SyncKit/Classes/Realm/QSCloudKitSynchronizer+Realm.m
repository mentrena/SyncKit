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
    return [[self applicationBackupRealmPath] stringByAppendingPathComponent:[self realmFileName]];
}

+ (NSString *)applicationBackupRealmPath
{
    return [[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"Realm"];
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

+ (RLMRealmConfiguration *)persistenceConfiguration
{
    RLMRealmConfiguration *configuration = [QSRealmChangeManager defaultPersistenceConfiguration];
    configuration.fileURL = [NSURL fileURLWithPath:[self realmPath]];
    return configuration;
}

+ (void)ensurePathAvailable
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:[self applicationBackupRealmPath]]) {
        [fileManager createDirectoryAtPath:[self applicationBackupRealmPath] withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

+ (CKRecordZoneID *)defaultCustomZoneID
{
    return [[CKRecordZoneID alloc] initWithZoneName:@"QSCloudKitCustomZoneName" ownerName:CKOwnerDefaultName];
}

+ (QSCloudKitSynchronizer *)cloudKitSynchronizerWithContainerName:(NSString *)containerName realmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration
{
    [self ensurePathAvailable];
    QSRealmChangeManager *changeManager = [[QSRealmChangeManager alloc] initWithPersistenceRealmConfiguration:[self persistenceConfiguration] targetRealmConfiguration:targetRealmConfiguration recordZoneID:[self defaultCustomZoneID]];
    QSCloudKitSynchronizer *synchronizer = [[QSCloudKitSynchronizer alloc] initWithContainerIdentifier:containerName recordZoneID:[self defaultCustomZoneID] changeManager:changeManager];
    return synchronizer;
}

@end
