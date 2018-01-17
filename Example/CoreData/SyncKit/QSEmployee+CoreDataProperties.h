//
//  QSEmployee+CoreDataProperties.h
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 11/01/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//
//

#import "QSEmployee.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSEmployee (CoreDataProperties)

+ (NSFetchRequest<QSEmployee *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, retain) NSData *photo;
@property (nullable, nonatomic, copy) NSNumber *sortIndex;
@property (nullable, nonatomic, retain) QSCompany *company;

@end

NS_ASSUME_NONNULL_END
