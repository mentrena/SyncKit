//
//  QSTestEntity+CoreDataProperties.h
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 18/10/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//
//

#import "QSTestEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSTestEntity (CoreDataProperties)

+ (NSFetchRequest<QSTestEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, retain) NSArray *names;

@end

NS_ASSUME_NONNULL_END
