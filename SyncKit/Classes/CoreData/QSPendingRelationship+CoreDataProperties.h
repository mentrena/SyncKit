//
//  QSPendingRelationship+CoreDataProperties.h
//  Pods
//
//  Created by Manuel Entrena on 10/07/2016.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "QSPendingRelationship.h"

NS_ASSUME_NONNULL_BEGIN

@interface QSPendingRelationship (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *relationshipName;
@property (nullable, nonatomic, retain) NSString *targetIdentifier;
@property (nullable, nonatomic, retain) QSSyncedEntity *forEntity;

@end

NS_ASSUME_NONNULL_END
