//
//  QSEntityIdentifierUpdateMigrationPolicy.m
//  Pods
//
//  Created by Manuel Entrena on 03/01/2017.
//
//

#import "QSEntityIdentifierUpdateMigrationPolicy.h"
#import "QSSyncedEntity+CoreDataClass.h"
#import "QSPrimaryKey.h"
#import "NSManagedObjectContext+QSFetch.h"

static QSCoreDataStack *_stack = nil;

@implementation QSEntityIdentifierUpdateMigrationPolicy

+ (QSCoreDataStack *)stack
{
    return _stack;
}

+ (void)setCoreDataStack:(QSCoreDataStack *)stack
{
    _stack = stack;
}

- (QSSyncedEntity *)syncedEntityWithOriginObjectIdentifier:(NSString *)objectIdentifier
{
    NSError *error = nil;
    NSArray *fetchedObjects = [_stack.managedObjectContext executeFetchRequestWithEntityName:@"QSSyncedEntity"
                                                                                   predicate:[NSPredicate predicateWithFormat:@"originObjectID == %@", objectIdentifier]
                                                                                       error:&error];
    return [fetchedObjects firstObject];
}

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError * _Nullable __autoreleasing *)error
{
    NSString *entityType = sInstance.entity.name;
    NSString *primaryKey = [NSClassFromString(entityType) primaryKey];
    if (primaryKey) {
        __block NSString *identifier = nil;
        if (_stack) {
            [_stack.managedObjectContext performBlockAndWait:^{
                QSSyncedEntity *syncedEntity = [self syncedEntityWithOriginObjectIdentifier:[sInstance.objectID.URIRepresentation absoluteString]];
                identifier = [syncedEntity.identifier substringFromIndex:entityType.length + 1];
                if (identifier) {
                    syncedEntity.originObjectID = identifier;
                    [_stack.managedObjectContext save:nil];
                }
            }];
        }
        
        for (NSPropertyMapping *attributeMapping in mapping.attributeMappings) {
            if ([attributeMapping.name isEqualToString:primaryKey]) {
                if (identifier) {
                    [attributeMapping setValueExpression:[NSExpression expressionForConstantValue:identifier]];
                } else {
                    [attributeMapping setValueExpression:[NSExpression expressionForConstantValue:[[NSUUID UUID] UUIDString]]];
                }
            }
        }
    }
    
    return [super  createDestinationInstancesForSourceInstance:sInstance entityMapping:mapping manager:manager error:error];
}

@end
