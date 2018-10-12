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
@property (nonatomic, assign) NSManagedObjectContextConcurrencyType concurrencyType;

@property (nonatomic, copy) NSURL *storeURL;
@property (nonatomic, copy) NSString *storeType;
@property (nonatomic, assign) BOOL useDispatchImmediatelyContext;

@end

@implementation QSCoreDataStack

- (BOOL)ensureStoreDirectoryExists
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSString * storeDirectory = [[self.storeURL path] stringByDeletingLastPathComponent];
    if ([fileManager fileExistsAtPath:storeDirectory] == NO) {
        if (![fileManager createDirectoryAtPath:storeDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
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
        self.managedObjectContext = [[QSManagedObjectContext alloc] initWithConcurrencyType:self.concurrencyType];
    } else {
        self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:self.concurrencyType];
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
    @try {
    self.store = [self.persistentStoreCoordinator addPersistentStoreWithType:self.storeType
                                                               configuration:nil
                                                                         URL:self.storeURL
                                                                     options:options
                                                                       error:&error];
    } @catch(NSException *error) {
        NSLog(@"error: %@", error);
    }
    
    if (!self.store) {
        abort();
    }
}

- (instancetype)initWithStoreType:(NSString *)storeType model:(NSManagedObjectModel *)model storePath:(NSString *)storePath
{
    return [self initWithStoreType:storeType model:model storePath:storePath concurrencyType:NSPrivateQueueConcurrencyType dispatchImmediately:NO];
}

- (instancetype)initWithStoreType:(NSString *)storeType model:(NSManagedObjectModel *)model storePath:(NSString *)storePath concurrencyType:(NSManagedObjectContextConcurrencyType)concurrencyType
{
    return [self initWithStoreType:storeType model:model storePath:storePath concurrencyType:concurrencyType dispatchImmediately:NO];
}

- (instancetype)initWithStoreType:(NSString *)storeType model:(NSManagedObjectModel *)model storePath:(NSString *)storePath concurrencyType:(NSManagedObjectContextConcurrencyType)concurrencyType dispatchImmediately:(BOOL)dispatchImmediately
{
    self = [super init];
    if (self) {
        self.useDispatchImmediatelyContext = dispatchImmediately;
        self.storeType = storeType;
        self.model = model;
        self.concurrencyType = concurrencyType;
        self.storeURL = storePath? [NSURL fileURLWithPath:storePath] : nil;
        [self initializeStack];
        [self loadStore];
    }
    return self;
}

- (void)deleteStore
{
    [self.managedObjectContext performBlockAndWait:^{
        [self.managedObjectContext reset];
    }];
 
    NSError *error = nil;
    [self.persistentStoreCoordinator removePersistentStore:self.store error:&error];
    self.managedObjectContext = nil;
    [[NSFileManager defaultManager] removeItemAtURL:self.storeURL error:&error];
}

@end
