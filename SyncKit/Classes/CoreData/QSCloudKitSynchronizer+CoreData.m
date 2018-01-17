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
    if (!suiteName) {
        return [self applicationDocumentsDirectory];
    }
    return [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:suiteName] path];
}

+ (NSString *)applicationStoresPathWithAppGroup:(NSString *)suiteName
{
    return [[self applicationDocumentsDirectoryForAppGroup:suiteName] stringByAppendingPathComponent:@"Stores"];
}

+ (NSString *)storePath
{
    return [self storePathWithAppGroup:nil];
}

+ (NSString *)storePathWithAppGroup:(NSString *)suiteName
{
    return [[self applicationStoresPathWithAppGroup:suiteName] stringByAppendingPathComponent:[self storeFileName]];
}

+ (NSString *)storeFileName;
{
    return @"QSSyncStore";
}

+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context
{
    return [self cloudKitPrivateSynchronizerWithContainerName:containerName managedObjectContext:context suiteName:nil];
}

+ (QSCloudKitSynchronizer *)cloudKitPrivateSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context suiteName:(NSString *)suiteName
{
    QSDefaultCoreDataAdapterDelegate *delegate = [QSDefaultCoreDataAdapterDelegate sharedInstance];
    QSCoreDataStack *stack = [[QSCoreDataStack alloc] initWithStoreType:NSSQLiteStoreType model:[QSCoreDataAdapter persistenceModel] storePath:[self storePathWithAppGroup:suiteName]];
    QSCoreDataAdapter *adapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:stack targetContext:context recordZoneID:[self defaultCustomZoneID] delegate:delegate];
    NSUserDefaults *suiteUserDefaults = suiteName ? [[NSUserDefaults alloc] initWithSuiteName:suiteName] : [NSUserDefaults standardUserDefaults];
    CKContainer *container = [CKContainer containerWithIdentifier:containerName];
    QSCloudKitSynchronizer *synchronizer = [[QSCloudKitSynchronizer alloc] initWithIdentifier:@"DefaultCoreDataPrivateSynchronizer" containerIdentifier:containerName database:container.privateCloudDatabase adapterProvider:nil keyValueStore:suiteUserDefaults];
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
    if ([QSEntityIdentifierUpdateMigrationPolicy stack] == nil && [[NSFileManager defaultManager] fileExistsAtPath:[self storePath]]) {
        QSCoreDataStack *stack = [[QSCoreDataStack alloc] initWithStoreType:NSSQLiteStoreType model:[QSCoreDataAdapter persistenceModel] storePath:[self storePath]];
        [QSEntityIdentifierUpdateMigrationPolicy setCoreDataStack:stack];
    }
    return [[QSEntityIdentifierUpdateMigrationPolicy alloc] init];
}

@end
