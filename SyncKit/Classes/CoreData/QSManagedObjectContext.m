//
//  QSManagedObjectContext.m
//  Pods
//
//  Created by Manuel Entrena on 29/07/2016.
//
//

#import "QSManagedObjectContext.h"

@implementation QSManagedObjectContext

- (void)performBlock:(void(^)())block
{
    [self performBlockAndWait:block];
}

@end
