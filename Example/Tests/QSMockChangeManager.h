//
//  QSMockChangeManager.h
//  QSCloudKitSynchronizer
//
//  Created by Manuel Entrena on 23/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SyncKit/QSChangeManager.h>

@interface QSMockChangeManager : NSObject <QSChangeManager>

@property (nonatomic, strong) NSArray *objects;

- (void)markForUpload:(NSArray *)objects;
- (void)markForDeletion:(NSArray *)objects;

@end
