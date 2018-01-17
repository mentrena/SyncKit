//
//  QSEmployee+CoreDataProperties.m
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 11/01/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//
//

#import "QSEmployee+CoreDataProperties.h"

@implementation QSEmployee (CoreDataProperties)

+ (NSFetchRequest<QSEmployee *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"QSEmployee"];
}

@dynamic identifier;
@dynamic name;
@dynamic photo;
@dynamic sortIndex;
@dynamic company;

@end
