//
//  QSCloudKitSynchronizer+MultiFetchedResultsController.h
//  Pods
//
//  Created by Manuel Entrena on 20/04/2018.
//

#import <Foundation/Foundation.h>
#import "QSCoreDataMultiFetchedResultsController.h"

@interface QSCloudKitSynchronizer (MultiFetchedResultsController)

// Can only have one of these
- (QSCoreDataMultiFetchedResultsController *)multiFetchedResultsControllerWithFetchRequest:(NSFetchRequest *)fetchRequest;

@end
