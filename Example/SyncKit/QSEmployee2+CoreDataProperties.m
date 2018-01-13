//
//  QSEmployee2+CoreDataProperties.m
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 11/01/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//
//

#import "QSEmployee2+CoreDataProperties.h"

@implementation QSEmployee2 (CoreDataProperties)

+ (NSFetchRequest<QSEmployee2 *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"QSEmployee2"];
}

@dynamic identifier;
@dynamic name;
@dynamic photo;
@dynamic sortIndex;
@dynamic company;

@end
