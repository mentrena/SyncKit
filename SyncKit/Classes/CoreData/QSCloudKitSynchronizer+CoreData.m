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

+ (NSString *)applicationStoresPath
{
    return [[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"Stores"];
}

+ (NSString *)storePath
{
    return [[self applicationStoresPath] stringByAppendingPathComponent:[self storeFileName]];
}

+ (NSString *)storeFileName
{
    return @"QSSyncStore";
    //    return [self.containerIdentifier stringByAppendingString:@"QSSyncStore"];
}

+ (CKRecordZoneID *)defaultCustomZoneID
{
    return [[CKRecordZoneID alloc] initWithZoneName:QSCloudKitCustomZoneName ownerName:CKOwnerDefaultName];
}

+ (QSCloudKitSynchronizer *)cloudKitSynchronizerWithContainerName:(NSString *)containerName managedObjectContext:(NSManagedObjectContext *)context changeManagerDelegate:(id<QSCoreDataChangeManagerDelegate>)delegate
{
    QSCoreDataStack *stack = [[QSCoreDataStack alloc] initWithStoreType:NSSQLiteStoreType model:[QSCoreDataChangeManager persistenceModel] storePath:[self storePath]];
    QSCoreDataChangeManager *changeManager = [[QSCoreDataChangeManager alloc] initWithPersistenceStack:stack targetContext:context recordZoneID:[self defaultCustomZoneID] delegate:delegate];
    QSCloudKitSynchronizer *synchronizer = [[QSCloudKitSynchronizer alloc] initWithContainerIdentifier:containerName recordZoneID:[self defaultCustomZoneID] changeManager:changeManager];
    return synchronizer;
}

@end
