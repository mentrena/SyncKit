//
//  QSCoreDataMultiFetchedResultsController.m
//  Pods
//
//  Created by Manuel Entrena on 18/04/2018.
//

#import "QSCoreDataMultiFetchedResultsController.h"
#import "QSCoreDataAdapter.h"

@interface QSCoreDataMultiFetchedResultsController () <QSDefaultCoreDataStackProviderDelegate>

@property (nonatomic, strong) NSMutableDictionary *controllersPerZoneIDDictionary;
@property (nonatomic, readwrite, copy) NSArray<NSFetchedResultsController *> *fetchedResultsControllers;
@property (nonatomic, readwrite, strong) NSFetchRequest *fetchRequest;
@property (nonatomic, strong) QSDefaultCoreDataStackProvider *provider;

@end

@implementation QSCoreDataMultiFetchedResultsController

- (instancetype)initWithStackProvider:(QSDefaultCoreDataStackProvider *)provider fetchRequest:(NSFetchRequest *)fetchRequest
{
    self = [super init];
    if (self) {
        self.fetchRequest = fetchRequest;
        self.provider = provider;
        provider.delegate = self;
        self.controllersPerZoneIDDictionary = [NSMutableDictionary dictionary];
        [self updateFetchedResultsControllers];
    }
    return self;
}

- (void)setDelegate:(id<QSCoreDataMultiFetchedResultsControllerDelegate>)delegate
{
    _delegate = delegate;
    for (NSFetchedResultsController *controller in self.fetchedResultsControllers) {
        controller.delegate = delegate;
    }
}

- (void)updateFetchedResultsControllers
{
    NSMutableArray *controllers = [NSMutableArray array];
    [self.provider.adapterDictionary enumerateKeysAndObjectsUsingBlock:^(CKRecordZoneID *  _Nonnull zoneID, QSCoreDataAdapter *  _Nonnull adapter, BOOL * _Nonnull stop) {
        NSFetchedResultsController *fetchedResultsController = [self fetchedResultsControllerForAdapter:adapter];
        [controllers addObject:fetchedResultsController];
        self.controllersPerZoneIDDictionary[zoneID] = fetchedResultsController;
    }];
    
    self.fetchedResultsControllers = controllers;
}

- (NSFetchedResultsController *)fetchedResultsControllerForAdapter:(QSCoreDataAdapter *)adapter
{
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:self.fetchRequest managedObjectContext:adapter.targetContext sectionNameKeyPath:nil cacheName:nil];
    [fetchedResultsController performFetch:nil];
    fetchedResultsController.delegate = self.delegate;
    return fetchedResultsController;
}

- (void)provider:(QSDefaultCoreDataStackProvider *)provider didAddAdapter:(QSCoreDataAdapter *)adapter forZoneID:(CKRecordZoneID *)zoneID
{
    NSFetchedResultsController *newController = [self fetchedResultsControllerForAdapter:adapter];
    self.fetchedResultsControllers = [self.fetchedResultsControllers arrayByAddingObject:newController];
    self.controllersPerZoneIDDictionary[zoneID] = newController;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate multiFetchedResultsControllerDidChangeControllers:self];
    });
}

- (void)provider:(QSDefaultCoreDataStackProvider *)provider didRemoveAdapterForZoneID:(CKRecordZoneID *)zoneID
{
    NSFetchedResultsController *removedController = self.controllersPerZoneIDDictionary[zoneID];
    if (removedController) {
        NSMutableArray *controllers = [self.fetchedResultsControllers mutableCopy];
        [controllers removeObject:removedController];
        self.fetchedResultsControllers = controllers;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate multiFetchedResultsControllerDidChangeControllers:self];
    });
}

@end
