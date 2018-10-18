//
//  QSTestEntity+CoreDataClass.h
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 18/10/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <SyncKit/QSPrimaryKey.h>

@class NSArray;

NS_ASSUME_NONNULL_BEGIN

@interface QSTestEntity : NSManagedObject <QSPrimaryKey>

@end

NS_ASSUME_NONNULL_END

#import "QSTestEntity+CoreDataProperties.h"
