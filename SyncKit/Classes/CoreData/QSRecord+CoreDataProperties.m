//
//  QSRecord+CoreDataProperties.m
//  
//
//  Created by Manuel Entrena on 22/01/2018.
//
//

#import "QSRecord+CoreDataProperties.h"

@implementation QSRecord (CoreDataProperties)

+ (NSFetchRequest<QSRecord *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"QSRecord"];
}

@dynamic encodedRecord;
@dynamic forEntity;

@end
