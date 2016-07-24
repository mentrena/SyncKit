//
//  QSEmployee+CoreDataProperties.h
//  SyncKit
//
//  Created by Manuel Entrena on 28/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "QSEmployee.h"

NS_ASSUME_NONNULL_BEGIN

@interface QSEmployee (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSNumber *sortIndex;
@property (nullable, nonatomic, retain) QSCompany *company;

@end

NS_ASSUME_NONNULL_END
