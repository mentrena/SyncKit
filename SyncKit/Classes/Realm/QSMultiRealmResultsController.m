//
//  QSMultiRealmResultsController.m
//  Pods
//
//  Created by Manuel Entrena on 27/05/2018.
//

#import "QSMultiRealmResultsController.h"
#import "QSRealmAdapter.h"
#import <SyncKit/SyncKit-Swift.h>
#import <Realm/Realm.h>

@interface QSMultiRealmResultsController ()

@property (nonatomic, strong) NSArray<RLMResults *> *results;
@property (nonatomic, strong) Class objectClass;
@property (nonatomic, strong) NSPredicate *predicate;
@property (nonatomic, strong) QSDefaultRealmProvider *provider;

@end

@implementation QSMultiRealmResultsController

- (instancetype)initWithRealmProvider:(QSDefaultRealmProvider *)provider fetchObjectClass:(Class)objectClass predicate:(NSPredicate *)predicate
{
    self = [super init];
    if (self) {
        self.objectClass = objectClass;
        self.predicate = predicate;
        self.provider = provider;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeAdapters:) name:NSNotification.QSDefaultRealmProviderDidAddAdapterNotification object:provider];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeAdapters:) name:NSNotification.QSDefaultRealmProviderDidRemoveAdapterNotification object:provider];
        [self updateResults];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateResults
{
    NSMutableArray *_results = [NSMutableArray array];
    
    [self.provider.realms enumerateKeysAndObjectsUsingBlock:^(CKRecordZoneID * _Nonnull zoneID, RLMRealmConfiguration * _Nonnull realmConfiguration, BOOL * _Nonnull stop) {
        
        RLMRealm *realm = [RLMRealm realmWithConfiguration:realmConfiguration error:nil];
        RLMResults *results = [self.objectClass objectsInRealm:realm withPredicate:self.predicate];
        [_results addObject:results];
    }];
    self.results = [_results copy];
}

- (void)didChangeAdapters:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateResults];
        [self.delegate multiRealmResultsControllerDidChangeRealms:self];
    });
}

@end
