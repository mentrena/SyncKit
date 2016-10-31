//
//  QSRecord+CoreDataProperties.h
//  Pods
//
//  Created by Manuel Entrena on 22/10/2016.
//
//

#import "QSRecord+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSRecord (CoreDataProperties)

+ (NSFetchRequest *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *encodedRecord;
@property (nullable, nonatomic, retain) QSSyncedEntity *forEntity;

@end

NS_ASSUME_NONNULL_END
