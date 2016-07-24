//
//  QSCompany+CoreDataProperties.h
//  SyncKit
//
//  Created by Manuel Entrena on 28/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "QSCompany.h"

NS_ASSUME_NONNULL_BEGIN

@interface QSCompany (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSNumber *sortIndex;
@property (nullable, nonatomic, retain) NSSet<NSManagedObject *> *employees;

@end

@interface QSCompany (CoreDataGeneratedAccessors)

- (void)addEmployeesObject:(NSManagedObject *)value;
- (void)removeEmployeesObject:(NSManagedObject *)value;
- (void)addEmployees:(NSSet<NSManagedObject *> *)values;
- (void)removeEmployees:(NSSet<NSManagedObject *> *)values;

@end

NS_ASSUME_NONNULL_END
