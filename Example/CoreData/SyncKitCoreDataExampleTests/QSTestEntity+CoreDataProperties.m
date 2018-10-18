//
//  QSTestEntity+CoreDataProperties.m
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 18/10/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//
//

#import "QSTestEntity+CoreDataProperties.h"

@implementation QSTestEntity (CoreDataProperties)

+ (NSFetchRequest<QSTestEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"QSTestEntity"];
}

@dynamic identifier;
@dynamic names;

@end
