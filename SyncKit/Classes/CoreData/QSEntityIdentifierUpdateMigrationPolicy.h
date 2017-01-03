//
//  QSEntityIdentifierUpdateMigrationPolicy.h
//  Pods
//
//  Created by Manuel Entrena on 03/01/2017.
//
//

#import <CoreData/CoreData.h>
#import "QSCoreDataStack.h"

@interface QSEntityIdentifierUpdateMigrationPolicy : NSEntityMigrationPolicy

+ (QSCoreDataStack *)stack;
+ (void)setCoreDataStack:(QSCoreDataStack *)stack;

@end
