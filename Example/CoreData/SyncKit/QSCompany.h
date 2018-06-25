//
//  QSCompany.h
//  SyncKit
//
//  Created by Manuel Entrena on 30/12/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <SyncKit/QSPrimaryKey.h>

@class QSEmployee;

NS_ASSUME_NONNULL_BEGIN

@interface QSCompany : NSManagedObject <QSPrimaryKey>

@end

NS_ASSUME_NONNULL_END

#import "QSCompany+CoreDataProperties.h"
