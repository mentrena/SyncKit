//
//  QSServerToken+CoreDataProperties.m
//  
//
//  Created by Manuel Entrena on 24/03/2018.
//
//

#import "QSServerToken+CoreDataProperties.h"

@implementation QSServerToken (CoreDataProperties)

+ (NSFetchRequest<QSServerToken *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"QSServerToken"];
}

@dynamic token;

@end
