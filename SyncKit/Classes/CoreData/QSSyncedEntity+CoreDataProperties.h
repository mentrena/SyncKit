//
//  QSSyncedEntity+CoreDataProperties.h
//  Pods
//
//  Created by Manuel Entrena on 10/07/2016.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "QSSyncedEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface QSSyncedEntity (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *changedKeys;
@property (nullable, nonatomic, retain) NSString *entityType;
@property (nullable, nonatomic, retain) NSString *identifier;
@property (nullable, nonatomic, retain) NSNumber *state;
@property (nullable, nonatomic, retain) NSDate *updated;
@property (nullable, nonatomic, retain) QSOriginObjectIdentifier *originIdentifier;
@property (nullable, nonatomic, retain) NSSet<QSPendingRelationship *> *pendingRelationships;
@property (nullable, nonatomic, retain) QSRecord *record;

@end

@interface QSSyncedEntity (CoreDataGeneratedAccessors)

- (void)addPendingRelationshipsObject:(QSPendingRelationship *)value;
- (void)removePendingRelationshipsObject:(QSPendingRelationship *)value;
- (void)addPendingRelationships:(NSSet<QSPendingRelationship *> *)values;
- (void)removePendingRelationships:(NSSet<QSPendingRelationship *> *)values;

@end

NS_ASSUME_NONNULL_END
