//
//  QSCloudKitSynchronizer+MultiFetchedResultsController.m
//  Pods
//
//  Created by Manuel Entrena on 20/04/2018.
//

#import "QSCloudKitSynchronizer+MultiFetchedResultsController.h"

@implementation QSCloudKitSynchronizer (MultiFetchedResultsController)

- (QSCoreDataMultiFetchedResultsController *)multiFetchedResultsControllerWithFetchRequest:(NSFetchRequest *)fetchRequest
{
    QSDefaultCoreDataStackProvider *provider = (QSDefaultCoreDataStackProvider *)self.adapterProvider;
    if (![provider isKindOfClass:[QSDefaultCoreDataStackProvider class]]) {
        return nil;
    }
    
    return [[QSCoreDataMultiFetchedResultsController alloc] initWithStackProvider:provider fetchRequest:fetchRequest];
}

@end
