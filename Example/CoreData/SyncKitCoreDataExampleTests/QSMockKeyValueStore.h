//
//  QSMockKeyValueStore.h
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 22/12/2017.
//  Copyright © 2017 Manuel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SyncKit/QSKeyValueStore.h>

@interface QSMockKeyValueStore : NSObject <QSKeyValueStore>

- (void)clear;

@end
