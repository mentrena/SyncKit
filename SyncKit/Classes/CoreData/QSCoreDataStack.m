//
//  QSCoreDataStack.m
//  Pods
//
//  Created by Manuel Entrena on 14/07/2016.
//
//

#import "QSCoreDataStack.h"
#import "QSManagedObjectContext.h"

@interface QSCoreDataStack ()

@property (nonatomic, readwrite, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, strong) NSManagedObjectModel *model;
@property (nonatomic, strong) NSPersistentStore *store;

@property (nonatomic, copy) NSURL *storeURL;
@property (nonatomic, copy) NSString *storeType;
@property (nonatomic, assign) BOOL useDispatchImmediatelyContext;

@end

@implementation QSCoreDataStack

- (NSString *)applicationDocumentsDirectory
{
#if TARGET_OS_IPHONE
    return [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask,YES) lastObject];
#else
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    return [[[urls lastObject] URLByAppendingPathComponent:@"QSCoreDataStack"] path];
#endif
}

- (NSString *)applicationStoresPath
{
    return [[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"Stores"];
}

- (BOOL)ensureStoreDirectoryExists
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSString * path = [self applicationStoresPath];
    if ([fileManager fileExistsAtPath:path] == NO) {
        if (![fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error]) {
            DLog(@"QSCoreDataStack: FAILED to create directory: %@ :%@",path, error);
            return NO;
        }
    }
    return YES;
}

- (void)initializeStack
{
    [self ensureStoreDirectoryExists];
    
    self.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.model];
    
    if (self.useDispatchImmediatelyContext) {
        self.managedObjectContext = [[QSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    } else {
        self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    }
    [self.managedObjectContext performBlockAndWait:^{
        [self.managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
        [self.managedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
    }];
}

- (void)loadStore
{
    if (self.store) {
        return; // Don’t load store if it’s already loaded
    }
    
    NSDictionary *options;
    if (self.storeURL) {
        options = @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES};
    }
    NSError *error = nil;
    self.store = [self.persistentStoreCoordinator addPersistentStoreWithType:self.storeType
                                                               configuration:nil
                                                                         URL:self.storeURL
                                                                     options:options
                                                                       error:&error];
    if (!self.store) {
        DLog(@"Failed to add store. Error: %@", error);
        abort();
    } else {
        DLog(@"Successfully added store: %@", self.store);
    }
}

- (instancetype)initWithStoreType:(NSString *)storeType model:(NSManagedObjectModel *)model storePath:(NSString *)storePath
{
    return [self initWithStoreType:storeType model:model storePath:storePath dispatchImmediately:NO];
}

- (instancetype)initWithStoreType:(NSString *)storeType model:(NSManagedObjectModel *)model storePath:(NSString *)storePath dispatchImmediately:(BOOL)dispatchImmediately
{
    self = [super init];
    if (self) {
        self.useDispatchImmediatelyContext = dispatchImmediately;
        self.storeType = storeType;
        self.model = model;
        self.storeURL = storePath? [NSURL fileURLWithPath:storePath] : nil;
        [self initializeStack];
        [self loadStore];
    }
    return self;
}

- (void)deleteStore
{
    NSError *error = nil;
    [self.managedObjectContext reset];
    [self.persistentStoreCoordinator removePersistentStore:self.store error:&error];
    self.managedObjectContext = nil;
    [[NSFileManager defaultManager] removeItemAtURL:self.storeURL error:&error];
}

@end
