//
//  QSMultiRealmResultsController.h
//  Pods
//
//  Created by Manuel Entrena on 27/05/2018.
//

#import <Foundation/Foundation.h>
@import CloudKit;
@import Realm;

@class QSDefaultRealmProvider;
@class QSMultiRealmResultsController;

@protocol QSMultiRealmResultsControllerDelegate

- (void)multiRealmResultsControllerDidChangeRealms:(QSMultiRealmResultsController *)controller;

@end

@interface QSMultiRealmResultsController : NSObject

@property (nonatomic, readonly) NSArray<RLMResults *> *results;

@property (nonatomic, readonly) Class objectClass;
@property (nonatomic, readonly) NSPredicate *predicate;
@property (nonatomic, readonly) QSDefaultRealmProvider *provider;
@property (nonatomic, weak) id<QSMultiRealmResultsControllerDelegate> delegate;

- (instancetype)initWithRealmProvider:(QSDefaultRealmProvider *)provider fetchObjectClass:(Class)objectClass predicate:(NSPredicate *)predicate;

@end
