//
//  QSMockCoreDataAdapter.m
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 11/05/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import "QSMockCoreDataAdapter.h"

@implementation QSMockCoreDataAdapter

- (NSManagedObjectContext *)targetContext
{
    return self.contextValue;
}

@end
