//
//  NSManagedObjectContext+QSCloudKit.h
//  QuikstudyOSX
//
//  Created by Manuel Entrena on 09/07/2016.
//  Copyright © 2016 Manuel Entrena. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObjectContext (QSFetch)

- (NSArray *)executeFetchRequestWithEntityName:(NSString *)entityName error:(NSError **)error;
- (NSArray *)executeFetchRequestWithEntityName:(NSString *)entityName predicate:(NSPredicate *)predicate error:(NSError **)error;
- (NSArray *)executeFetchRequestWithEntityName:(NSString *)entityName predicate:(NSPredicate *)predicate fetchLimit:(NSInteger)limit error:(NSError **)error;
- (NSArray *)executeFetchRequestWithEntityName:(NSString *)entityName predicate:(NSPredicate *)predicate fetchLimit:(NSInteger)limit resultType:(NSFetchRequestResultType)resultType error:(NSError **)error;
- (NSArray *)executeFetchRequestWithEntityName:(NSString *)entityName predicate:(NSPredicate *)predicate fetchLimit:(NSInteger)limit resultType:(NSFetchRequestResultType)resultType propertiesToFetch:(NSArray *)propertiesToFetch error:(NSError **)error;


@end
