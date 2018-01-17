//
//  QSSyncedEntity+CoreDataProperties.m
//  
//
//  Created by Manuel Entrena on 24/03/2018.
//
//

#import "QSSyncedEntity+CoreDataProperties.h"

@implementation QSSyncedEntity (CoreDataProperties)

+ (NSFetchRequest<QSSyncedEntity *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"QSSyncedEntity"];
}

@dynamic changedKeys;
@dynamic entityType;
@dynamic identifier;
@dynamic originObjectID;
@dynamic state;
@dynamic updated;
@dynamic pendingRelationships;
@dynamic record;
@dynamic share;
@dynamic shareForEntity;

@end
