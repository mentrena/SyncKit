//
//  QSCompany+CoreDataProperties.h
//  SyncKit
//
//  Created by Manuel Entrena on 30/12/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import "QSCompany.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSCompany (CoreDataProperties)

@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSNumber *sortIndex;
@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, retain) NSSet<QSEmployee *> *employees;

@end

@interface QSCompany (CoreDataGeneratedAccessors)

- (void)addEmployeesObject:(QSEmployee *)value;
- (void)removeEmployeesObject:(QSEmployee *)value;
- (void)addEmployees:(NSSet<QSEmployee *> *)values;
- (void)removeEmployees:(NSSet<QSEmployee *> *)values;

@end

NS_ASSUME_NONNULL_END
