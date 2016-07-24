//
//  QSRecord+CoreDataProperties.h
//  Pods
//
//  Created by Manuel Entrena on 10/07/2016.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "QSRecord.h"

NS_ASSUME_NONNULL_BEGIN

@interface QSRecord (CoreDataProperties)

@property (nullable, nonatomic, retain) NSData *encodedRecord;
@property (nullable, nonatomic, retain) QSSyncedEntity *forEntity;

@end

NS_ASSUME_NONNULL_END
