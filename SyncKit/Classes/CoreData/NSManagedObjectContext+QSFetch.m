//
//  NSManagedObjectContext+QSCloudKit.m
//  QuikstudyOSX
//
//  Created by Manuel Entrena on 09/07/2016.
//  Copyright © 2016 Manuel Entrena. All rights reserved.
//

#import "NSManagedObjectContext+QSFetch.h"

@implementation NSManagedObjectContext (QSFetch)

- (NSArray *)executeFetchRequestWithEntityName:(NSString *)entityName error:(NSError **)error
{
    return [self executeFetchRequestWithEntityName:entityName predicate:nil fetchLimit:0 resultType:NSManagedObjectResultType error:error];
}
- (NSArray *)executeFetchRequestWithEntityName:(NSString *)entityName predicate:(NSPredicate *)predicate error:(NSError **)error
{
    return [self executeFetchRequestWithEntityName:entityName predicate:predicate fetchLimit:0 resultType:NSManagedObjectResultType error:error];
}

- (NSArray *)executeFetchRequestWithEntityName:(NSString *)entityName predicate:(NSPredicate *)predicate fetchLimit:(NSInteger)limit error:(NSError **)error
{
    return [self executeFetchRequestWithEntityName:entityName predicate:predicate fetchLimit:limit resultType:NSManagedObjectResultType error:error];
}

- (NSArray *)executeFetchRequestWithEntityName:(NSString *)entityName predicate:(NSPredicate *)predicate fetchLimit:(NSInteger)limit resultType:(NSFetchRequestResultType)resultType error:(NSError **)error
{
    return [self executeFetchRequestWithEntityName:entityName predicate:predicate fetchLimit:limit resultType:resultType propertiesToFetch:nil error:error];
}

- (NSArray *)executeFetchRequestWithEntityName:(NSString *)entityName predicate:(NSPredicate *)predicate fetchLimit:(NSInteger)limit resultType:(NSFetchRequestResultType)resultType propertiesToFetch:(NSArray *)propertiesToFetch error:(NSError **)error
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:self];
    [fetchRequest setEntity:entity];
    fetchRequest.resultType = resultType;
    fetchRequest.predicate = predicate;
    if (limit) {
        fetchRequest.fetchLimit = limit;
    }
    if (propertiesToFetch) {
        fetchRequest.propertiesToFetch = propertiesToFetch;
    }
    
    return [self executeFetchRequest:fetchRequest error:error];
}

@end
