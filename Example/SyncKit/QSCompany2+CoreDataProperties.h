//
//  QSCompany2+CoreDataProperties.h
//  SyncKit
//
//  Created by Manuel Entrena on 30/12/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import "QSCompany2.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSCompany2 (CoreDataProperties)

@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSNumber *sortIndex;
@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, retain) NSSet<QSEmployee2 *> *employees;

@end

@interface QSCompany2 (CoreDataGeneratedAccessors)

- (void)addEmployeesObject:(QSEmployee2 *)value;
- (void)removeEmployeesObject:(QSEmployee2 *)value;
- (void)addEmployees:(NSSet<QSEmployee2 *> *)values;
- (void)removeEmployees:(NSSet<QSEmployee2 *> *)values;

@end

NS_ASSUME_NONNULL_END
