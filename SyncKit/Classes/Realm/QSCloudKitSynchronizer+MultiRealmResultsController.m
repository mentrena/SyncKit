//
//  QSCloudKitSynchronizer+MultiRealmResultsController.m
//  Pods
//
//  Created by Manuel Entrena on 28/05/2018.
//

#import "QSCloudKitSynchronizer+MultiRealmResultsController.h"
#import <SyncKit/SyncKit-Swift.h>

@implementation QSCloudKitSynchronizer (MultiRealmResultsController)

- (QSMultiRealmResultsController *)multiRealmResultsControllerWithClass:(Class)objectClass predicate:(NSPredicate *)predicate
{
    QSDefaultRealmProvider *provider = (QSDefaultRealmProvider *)self.adapterProvider;
    if (![provider isKindOfClass:[QSDefaultRealmProvider class]]) {
        return nil;
    }
    
    return [[QSMultiRealmResultsController alloc] initWithRealmProvider:provider fetchObjectClass:objectClass predicate:predicate];
}

@end
