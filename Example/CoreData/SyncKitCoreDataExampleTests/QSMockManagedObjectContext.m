//
//  QSMockManagedObjectContext.m
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 11/05/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import "QSMockManagedObjectContext.h"

@implementation QSMockManagedObjectContext

- (BOOL)save:(NSError * _Nullable *)error
{
    self.saveCalled = YES;
    *error = self.saveError;
    return self.saveError == nil;
}

- (void)performBlock:(void (^)(void))block
{
    self.performBlockCalled = YES;
    [super performBlock:block];
}

- (void)performBlockAndWait:(void (^)(void))block
{
    self.performBlockAndWaitCalled = YES;
    [super performBlockAndWait:block];
}

@end
