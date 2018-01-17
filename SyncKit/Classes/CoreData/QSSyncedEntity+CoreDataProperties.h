//
//  QSSyncedEntity+CoreDataProperties.h
//  
//
//  Created by Manuel Entrena on 24/03/2018.
//
//

#import "QSSyncedEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSSyncedEntity (CoreDataProperties)

+ (NSFetchRequest<QSSyncedEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *changedKeys;
@property (nullable, nonatomic, copy) NSString *entityType;
@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, copy) NSString *originObjectID;
@property (nullable, nonatomic, copy) NSNumber *state;
@property (nullable, nonatomic, copy) NSDate *updated;
@property (nullable, nonatomic, retain) NSSet<QSPendingRelationship *> *pendingRelationships;
@property (nullable, nonatomic, retain) QSRecord *record;
@property (nullable, nonatomic, retain) QSSyncedEntity *share;
@property (nullable, nonatomic, retain) QSSyncedEntity *shareForEntity;

@end

@interface QSSyncedEntity (CoreDataGeneratedAccessors)

- (void)addPendingRelationshipsObject:(QSPendingRelationship *)value;
- (void)removePendingRelationshipsObject:(QSPendingRelationship *)value;
- (void)addPendingRelationships:(NSSet<QSPendingRelationship *> *)values;
- (void)removePendingRelationships:(NSSet<QSPendingRelationship *> *)values;

@end

NS_ASSUME_NONNULL_END
