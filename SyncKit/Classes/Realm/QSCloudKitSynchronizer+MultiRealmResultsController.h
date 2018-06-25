//
//  QSCloudKitSynchronizer+MultiRealmResultsController.h
//  Pods
//
//  Created by Manuel Entrena on 28/05/2018.
//

#import <SyncKit/SyncKit.h>
#import "QSMultiRealmResultsController.h"

@interface QSCloudKitSynchronizer (MultiRealmResultsController)

- (QSMultiRealmResultsController *)multiRealmResultsControllerWithClass:(Class)objectClass predicate:(NSPredicate *)predicate;

@end
