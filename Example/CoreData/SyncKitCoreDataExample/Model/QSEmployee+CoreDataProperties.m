//
//  QSEmployee+CoreDataProperties.m
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 08/05/2018.
//  Copyright © 2018 Manuel Entrena. All rights reserved.
//
//

#import "QSEmployee+CoreDataProperties.h"

@implementation QSEmployee (CoreDataProperties)

+ (NSFetchRequest<QSEmployee *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"QSEmployee"];
}

@dynamic identifier;
@dynamic name;
@dynamic photo;
@dynamic sortIndex;
@dynamic company;

@end
