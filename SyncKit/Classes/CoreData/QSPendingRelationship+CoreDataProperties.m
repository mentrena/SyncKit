//
//  QSPendingRelationship+CoreDataProperties.m
//  Pods
//
//  Created by Manuel Entrena on 22/10/2016.
//
//

#import "QSPendingRelationship+CoreDataProperties.h"

@implementation QSPendingRelationship (CoreDataProperties)

+ (NSFetchRequest *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"QSPendingRelationship"];
}

@dynamic relationshipName;
@dynamic targetIdentifier;
@dynamic forEntity;

@end
