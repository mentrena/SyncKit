//
//  QSCoreDataMultiFetchedResultsController.h
//  Pods
//
//  Created by Manuel Entrena on 18/04/2018.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "QSDefaultCoreDataStackProvider.h"

@class QSCoreDataMultiFetchedResultsController;

@protocol QSCoreDataMultiFetchedResultsControllerDelegate <NSFetchedResultsControllerDelegate>

- (void)multiFetchedResultsControllerDidChangeControllers:(QSCoreDataMultiFetchedResultsController *)controller;

@end

@interface QSCoreDataMultiFetchedResultsController : NSObject

@property (nonatomic, readonly) NSArray<NSFetchedResultsController *> *fetchedResultsControllers;
@property (nonatomic, weak) id<QSCoreDataMultiFetchedResultsControllerDelegate> delegate;
@property (nonatomic, readonly) NSFetchRequest *fetchRequest;

- (instancetype)initWithStackProvider:(QSDefaultCoreDataStackProvider *)provider fetchRequest:(NSFetchRequest *)fetchRequest;

@end
