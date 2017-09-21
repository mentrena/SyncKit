//
//  QSCloudKitSynchronizer+CoreData.m
//  Pods
//
//  Created by Manuel Entrena on 17/07/2016.
//
//

#import "QSCloudKitSynchronizer+CoreData.h"

static NSString * const QSCloudKitCustomZoneName = @"QSCloudKitCustomZoneName";

@implementation QSCloudKitSynchronizer (CoreData)

+ (NSString *)applicationDocumentsDirectory
{
#if TARGET_OS_IPHONE
    return [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask,YES) lastObject];
#else
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    return [[[urls lastObject] URLByAppendingPathComponent:@"com.mentrena.QSCloudKitSynchronizer"] path];
#endif
}

+ (NSString *)applicationDocumentsDirectoryForAppGroup:(NSString *)suiteName
{
    return [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:suiteName] path];
}

+ (NSString *)applicationStoresPath
{
    return [[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"Stores"];
}

+ (NSString *)applicationStoresPathWithAppGroup:(NSString *)suiteName
{
    return [[self applicationDocumentsDirectoryForAppGroup:suiteName] stringByAppendingPathComponent:@"Stores"];
}

+ (NSString *)storePath
{
    return [[self applicationStoresPath] stringByAppendingPathComponent:[self storeFileName]];
}

+ (NSString *)storePathWithAppGroup:(NSString *)suiteName
{
    return [[self applicationStoresPathWithAppGroup:suiteName] stringByAppendingPathComponent:[self storeFileName]];
}

+ (NSString *)storeFileName
{
    return @"QSSyncStore";
}

+ (CKRecordZoneID *)defaultCustomZoneID
{
    if (@available(iOS 10.0, macOS 10.12, watchOS 3.0, *)) {
        return [[CKRecordZoneID alloc] initWithZoneName:QSCloudKitCustomZoneName ownerName:CKCurrentUserDefaultName]
    }else{
        return [[CKRecordZoneID alloc] initWithZoneName:QSCloudKitCustomZoneName ownerName:CKOwnerDefaultName];
    }
}

+ (QSCloudKitSynchronizer *)cloudKitSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context changeManagerDelegate:(id<QSCoreDataChangeManagerDelegate>)delegate
{
    QSCoreDataStack *stack = [[QSCoreDataStack alloc] initWithStoreType:NSSQLiteStoreType model:[QSCoreDataChangeManager persistenceModel] storePath:[self storePath]];
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:stack targetContext:context recordZoneID:[self defaultCustomZoneID] delegate:delegate];
    QSCloudKitSynchronizer *synchronizer = [[QSCloudKitSynchronizer alloc] initWithContainerIdentifier:containerName recordZoneID:[self defaultCustomZoneID] changeManager:changeManager];
    return synchronizer;
}

+ (QSCloudKitSynchronizer *)cloudKitSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context changeManagerDelegate:(id<QSCoreDataChangeManagerDelegate>)delegate suiteName:(NSString *)suiteName
{
    QSCoreDataStack *stack = [[QSCoreDataStack alloc] initWithStoreType:NSSQLiteStoreType model:[QSCoreDataChangeManager persistenceModel] storePath:[self storePathWithAppGroup:suiteName]];
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:stack targetContext:context recordZoneID:[self defaultCustomZoneID] delegate:delegate];
    QSCloudKitSynchronizer *synchronizer = [[QSCloudKitSynchronizer alloc] initWithContainerIdentifier:containerName recordZoneID:[self defaultCustomZoneID] changeManager:changeManager suiteName:suiteName];
    return synchronizer;
}

+ (NSEntityMigrationPolicy *)updateIdentifierMigrationPolicy
{
    if ([QSEntityIdentifierUpdateMigrationPolicy stack] == nil && [[NSFileManager defaultManager] fileExistsAtPath:[self storePath]]) {
        QSCoreDataStack *stack = [[QSCoreDataStack alloc] initWithStoreType:NSSQLiteStoreType model:[QSCoreDataChangeManager persistenceModel] storePath:[self storePath]];
        [QSEntityIdentifierUpdateMigrationPolicy setCoreDataStack:stack];
    }
    return [[QSEntityIdentifierUpdateMigrationPolicy alloc] init];
}

@end
