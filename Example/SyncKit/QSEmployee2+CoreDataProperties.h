//
//  QSEmployee2+CoreDataProperties.h
//  SyncKit
//
//  Created by Manuel Entrena on 30/12/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import "QSEmployee2.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSEmployee2 (CoreDataProperties)

@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSNumber *sortIndex;
@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, retain) QSCompany2 *company;

@end

NS_ASSUME_NONNULL_END
