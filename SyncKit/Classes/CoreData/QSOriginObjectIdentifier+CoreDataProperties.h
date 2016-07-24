//
//  QSOriginObjectIdentifier+CoreDataProperties.h
//  Pods
//
//  Created by Manuel Entrena on 10/07/2016.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "QSOriginObjectIdentifier.h"

NS_ASSUME_NONNULL_BEGIN

@interface QSOriginObjectIdentifier (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *originObjectID;
@property (nullable, nonatomic, retain) QSSyncedEntity *forSyncedEntity;

@end

NS_ASSUME_NONNULL_END
