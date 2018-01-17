//
//  QSCompany+CoreDataProperties.m
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 08/05/2018.
//  Copyright © 2018 Manuel Entrena. All rights reserved.
//
//

#import "QSCompany+CoreDataProperties.h"

@implementation QSCompany (CoreDataProperties)

+ (NSFetchRequest<QSCompany *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"QSCompany"];
}

@dynamic identifier;
@dynamic name;
@dynamic sortIndex;
@dynamic employees;

@end
