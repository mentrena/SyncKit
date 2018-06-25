//
//  QSDefaultCoreDataStackProvider.m
//  Pods
//
//  Created by Manuel Entrena on 28/03/2018.
//

#import "QSDefaultCoreDataStackProvider.h"
#import "QSCoreDataStack.h"
#import "QSCoreDataAdapter.h"
#import "QSDefaultCoreDataAdapterDelegate.h"
@import CoreData;

static NSString * const QSDefaultCoreDataStackProviderTargetFileName = @"QSTargetStore";
static NSString * const QSDefaultCoreDataStackProviderPersistenceFileName = @"QSPersistenceStore";

@interface QSDefaultCoreDataStackProvider ()

@property (nonatomic, readwrite, copy) NSString *identifier;
@property (nonatomic, copy) NSString *suiteName;
@property (nonatomic, readwrite, strong) NSMutableDictionary *adapterDictionary;
@property (nonatomic, strong) NSMutableDictionary *coreDataStacks;
@property (nonatomic, strong) NSString *storeType;
@property (nonatomic, strong) NSManagedObjectModel *model;

@end

@implementation QSDefaultCoreDataStackProvider

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

- (NSString *)stackProviderStoresPathWithAppGroup:(NSString *)suiteName
{
    return [[[QSDefaultCoreDataStackProvider applicationDocumentsDirectoryForAppGroup:suiteName] stringByAppendingPathComponent:@"Stores"] stringByAppendingPathComponent:self.identifier];
}

- (id<QSModelAdapter>)adapterForCoreDataStackAt:(NSURL *)storeURL persistenceStackAt:(NSURL *)persistenceStoreURL recordZoneID:(CKRecordZoneID *)zoneID
{
    QSCoreDataStack *stack = [[QSCoreDataStack alloc] initWithStoreType:self.storeType model:self.model storePath:storeURL.path concurrencyType:NSMainQueueConcurrencyType];
    QSCoreDataStack *persistenceStack = [[QSCoreDataStack alloc] initWithStoreType:NSSQLiteStoreType model:[QSCoreDataAdapter persistenceModel] storePath:persistenceStoreURL.path];
    QSDefaultCoreDataAdapterDelegate *delegate = [QSDefaultCoreDataAdapterDelegate sharedInstance];
    QSCoreDataAdapter *adapter = [[QSCoreDataAdapter alloc] initWithPersistenceStack:persistenceStack targetContext:stack.managedObjectContext recordZoneID:zoneID delegate:delegate];
    self.coreDataStacks[zoneID] = stack;
    return adapter;
}

- (instancetype)initWithIdentifier:(NSString *)identifier storeType:(NSString *)storeType model:(NSManagedObjectModel *)model
{
    return [self initWithIdentifier:identifier storeType:storeType model:model appGroup:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier storeType:(NSString *)storeType model:(NSManagedObjectModel *)model appGroup:(NSString *)suiteName
{
    self = [super init];
    if (self) {
        self.adapterDictionary = [NSMutableDictionary dictionary];
        self.coreDataStacks = [NSMutableDictionary dictionary];
        self.identifier = identifier;
        self.storeType = storeType;
        self.model = model;
        self.suiteName = suiteName;
        [self bringUpDataStacks];
    }
    return self;
}

- (void)bringUpDataStacks
{
    NSURL *folderURL = [NSURL fileURLWithPath:[self stackProviderStoresPathWithAppGroup:self.suiteName]];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:folderURL includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
    for (NSURL *subfolderURL in enumerator) {
        NSString *folderName = [subfolderURL lastPathComponent];
        NSArray *zoneIDComponents = [folderName componentsSeparatedByString:@".zoneID."];
        CKRecordZoneID *zoneID = [[CKRecordZoneID alloc] initWithZoneName:zoneIDComponents[0] ownerName:zoneIDComponents[1]];
        NSURL *stackURL = [subfolderURL URLByAppendingPathComponent:QSDefaultCoreDataStackProviderTargetFileName];
        NSURL *persistenceURL = [subfolderURL URLByAppendingPathComponent:QSDefaultCoreDataStackProviderPersistenceFileName];
        id<QSModelAdapter> adapter = [self adapterForCoreDataStackAt:stackURL persistenceStackAt:persistenceURL recordZoneID:zoneID];
        self.adapterDictionary[zoneID] = adapter;
    }
}

- (NSURL *)directoryURL
{
    return [NSURL fileURLWithPath:[self stackProviderStoresPathWithAppGroup:self.suiteName]];
}

#pragma mark - QSCloudKitSynchronizerAdapterProvider

- (id<QSModelAdapter>)cloudKitSynchronizer:(QSCloudKitSynchronizer *)synchronizer modelAdapterForRecordZoneID:(CKRecordZoneID *)recordZoneID
{
    if (self.adapterDictionary[recordZoneID]) {
        return self.adapterDictionary[recordZoneID];
    }
    
    NSString *folderName = [NSString stringWithFormat:@"%@.zoneID.%@", recordZoneID.zoneName, recordZoneID.ownerName];
    NSURL *folderURL = [self.directoryURL URLByAppendingPathComponent:folderName];
    [[NSFileManager defaultManager] createDirectoryAtURL:folderURL withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSURL *stackURL = [folderURL URLByAppendingPathComponent:QSDefaultCoreDataStackProviderTargetFileName];
    NSURL *persistenceURL = [folderURL URLByAppendingPathComponent:QSDefaultCoreDataStackProviderPersistenceFileName];
    
    QSCoreDataAdapter *adapter = [self adapterForCoreDataStackAt:stackURL persistenceStackAt:persistenceURL recordZoneID:recordZoneID];
    self.adapterDictionary[recordZoneID] = adapter;
    
    [self.delegate provider:self didAddAdapter:adapter forZoneID:recordZoneID];
    
    return adapter;
}

- (void)cloudKitSynchronizer:(QSCloudKitSynchronizer *)synchronizer zoneWasDeletedWithZoneID:(CKRecordZoneID *)recordZoneID
{
    QSCoreDataAdapter *adapter = self.adapterDictionary[recordZoneID];
    BOOL adapterHasSyncedBefore = adapter.serverChangeToken != nil;
    if (adapter && adapterHasSyncedBefore) {
        
        [adapter deleteChangeTracking];
        QSCoreDataStack *targetStack = self.coreDataStacks[recordZoneID];
        [targetStack deleteStore];
        
        NSString *folderName = [NSString stringWithFormat:@"%@.zoneID.%@", recordZoneID.zoneName, recordZoneID.ownerName];
        NSURL *folderURL = [self.directoryURL URLByAppendingPathComponent:folderName];
        [[NSFileManager defaultManager] removeItemAtURL:folderURL error:nil];
        
        [self.adapterDictionary removeObjectForKey:recordZoneID];
        [self.coreDataStacks removeObjectForKey:recordZoneID];
        
        [synchronizer removeModelAdapter:adapter];
        
        [self.delegate provider:self didRemoveAdapterForZoneID:recordZoneID];
    }
}

@end
