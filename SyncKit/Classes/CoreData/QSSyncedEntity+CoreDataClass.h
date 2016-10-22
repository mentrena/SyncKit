//
//  QSSyncedEntity+CoreDataClass.h
//  Pods
//
//  Created by Manuel Entrena on 22/10/2016.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class QSPendingRelationship, QSRecord;

NS_ASSUME_NONNULL_BEGIN

@interface QSSyncedEntity : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "QSSyncedEntity+CoreDataProperties.h"
