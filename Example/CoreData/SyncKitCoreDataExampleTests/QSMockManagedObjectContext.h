//
//  QSMockManagedObjectContext.h
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 11/05/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface QSMockManagedObjectContext : NSManagedObjectContext

@property (nonatomic, assign) BOOL saveCalled;
@property (nonatomic, assign) BOOL performBlockCalled;
@property (nonatomic, assign) BOOL performBlockAndWaitCalled;

@property (nonatomic, strong) NSError *saveError;

@end
