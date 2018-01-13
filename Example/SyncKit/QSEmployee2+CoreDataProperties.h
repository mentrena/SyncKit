//
//  QSEmployee2+CoreDataProperties.h
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 11/01/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//
//

#import "QSEmployee2.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSEmployee2 (CoreDataProperties)

+ (NSFetchRequest<QSEmployee2 *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, retain) NSData *photo;
@property (nullable, nonatomic, copy) NSNumber *sortIndex;
@property (nullable, nonatomic, retain) QSCompany2 *company;

@end

NS_ASSUME_NONNULL_END
