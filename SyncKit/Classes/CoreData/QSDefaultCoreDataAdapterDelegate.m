//
//  QSDefaultCoreDataAdapterDelegate.m
//  Pods
//
//  Created by Manuel Entrena on 02/04/2018.
//

#import "QSDefaultCoreDataAdapterDelegate.h"

static QSDefaultCoreDataAdapterDelegate *_sharedInstance = nil;

@implementation QSDefaultCoreDataAdapterDelegate

- (void)coreDataAdapterRequestsContextSave:(QSCoreDataAdapter *)coreDataAdapter completion:(void(^)(NSError *error))completion
{
    __block NSError *error = nil;
    [coreDataAdapter.targetContext performBlockAndWait:^{
        [coreDataAdapter.targetContext save:&error];
    }];
    completion(error);
}

- (void)coreDataAdapter:(QSCoreDataAdapter *)coreDataAdapter didImportChanges:(NSManagedObjectContext *)importContext completion:(void(^)(NSError *error))completion
{
    __block NSError *error = nil;
    [importContext performBlockAndWait:^{
        [importContext save:&error];
    }];
    
    if (!error) {
        [coreDataAdapter.targetContext performBlockAndWait:^{
            [coreDataAdapter.targetContext save:&error];
        }];
    }
    completion(error);
}

+ (instancetype)sharedInstance
{
    if (_sharedInstance == nil) {
        _sharedInstance = [[QSDefaultCoreDataAdapterDelegate alloc] init];
    }
    return _sharedInstance;
}

@end
