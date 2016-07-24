//
//  QSSyncedEntity.h
//  Pods
//
//  Created by Manuel Entrena on 10/07/2016.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class QSOriginObjectIdentifier, QSPendingRelationship, QSRecord;

NS_ASSUME_NONNULL_BEGIN

@interface QSSyncedEntity : NSManagedObject

// Insert code here to declare functionality of your managed object subclass

@end

NS_ASSUME_NONNULL_END

#import "QSSyncedEntity+CoreDataProperties.h"
