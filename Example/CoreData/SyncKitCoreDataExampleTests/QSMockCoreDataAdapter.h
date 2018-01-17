//
//  QSMockCoreDataAdapter.h
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 11/05/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SyncKit/QSCoreDataAdapter.h>

@interface QSMockCoreDataAdapter : QSCoreDataAdapter

@property (nonatomic, strong) NSManagedObjectContext *contextValue;

@end
