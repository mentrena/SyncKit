//
//  QSRecord+CoreDataProperties.m
//  Pods
//
//  Created by Manuel Entrena on 22/10/2016.
//
//

#import "QSRecord+CoreDataProperties.h"

@implementation QSRecord (CoreDataProperties)

+ (NSFetchRequest *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"QSRecord"];
}

@dynamic encodedRecord;
@dynamic forEntity;

@end
