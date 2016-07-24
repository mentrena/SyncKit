//
//  QSSyncedEntity+CoreDataProperties.m
//  Pods
//
//  Created by Manuel Entrena on 10/07/2016.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "QSSyncedEntity+CoreDataProperties.h"

@implementation QSSyncedEntity (CoreDataProperties)

@dynamic changedKeys;
@dynamic entityType;
@dynamic identifier;
@dynamic state;
@dynamic updated;
@dynamic originIdentifier;
@dynamic pendingRelationships;
@dynamic record;

@end
