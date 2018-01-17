//
//  QSRecord+CoreDataProperties.h
//  
//
//  Created by Manuel Entrena on 22/01/2018.
//
//

#import "QSRecord+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSRecord (CoreDataProperties)

+ (NSFetchRequest<QSRecord *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *encodedRecord;
@property (nullable, nonatomic, retain) QSSyncedEntity *forEntity;

@end

NS_ASSUME_NONNULL_END
