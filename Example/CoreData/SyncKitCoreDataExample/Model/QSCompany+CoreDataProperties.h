//
//  QSCompany+CoreDataProperties.h
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 08/05/2018.
//  Copyright © 2018 Manuel Entrena. All rights reserved.
//
//

#import "QSCompany+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSCompany (CoreDataProperties)

+ (NSFetchRequest<QSCompany *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSNumber *sortIndex;
@property (nullable, nonatomic, retain) NSSet<QSEmployee *> *employees;

@end

@interface QSCompany (CoreDataGeneratedAccessors)

- (void)addEmployeesObject:(QSEmployee *)value;
- (void)removeEmployeesObject:(QSEmployee *)value;
- (void)addEmployees:(NSSet<QSEmployee *> *)values;
- (void)removeEmployees:(NSSet<QSEmployee *> *)values;

@end

NS_ASSUME_NONNULL_END
