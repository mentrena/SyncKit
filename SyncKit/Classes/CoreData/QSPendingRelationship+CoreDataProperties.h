//
//  QSPendingRelationship+CoreDataProperties.h
//  Pods
//
//  Created by Manuel Entrena on 22/10/2016.
//
//

#import "QSPendingRelationship+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSPendingRelationship (CoreDataProperties)

+ (NSFetchRequest *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *relationshipName;
@property (nullable, nonatomic, copy) NSString *targetIdentifier;
@property (nullable, nonatomic, retain) QSSyncedEntity *forEntity;

@end

NS_ASSUME_NONNULL_END
