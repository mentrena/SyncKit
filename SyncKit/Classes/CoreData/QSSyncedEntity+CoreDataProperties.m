//
//  QSSyncedEntity+CoreDataProperties.m
//  Pods
//
//  Created by Manuel Entrena on 22/10/2016.
//
//

#import "QSSyncedEntity+CoreDataProperties.h"

@implementation QSSyncedEntity (CoreDataProperties)

+ (NSFetchRequest *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"QSSyncedEntity"];
}

@dynamic changedKeys;
@dynamic entityType;
@dynamic identifier;
@dynamic state;
@dynamic updated;
@dynamic originObjectID;
@dynamic pendingRelationships;
@dynamic record;

@end
