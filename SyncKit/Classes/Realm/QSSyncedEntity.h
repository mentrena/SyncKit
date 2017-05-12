//
//  QSSyncedEntity.h
//  Pods
//
//  Created by Manuel Entrena on 06/05/2017.
//
//

#import <Realm/Realm.h>

@class QSRecord;

@interface QSSyncedEntity : RLMObject

@property (nullable, nonatomic, copy) NSString *changedKeys;
@property (nullable, nonatomic, copy) NSString *entityType;
@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, copy) NSNumber<RLMInt> *state;
@property (nullable, nonatomic, copy) NSDate *updated;
@property (nullable, nonatomic, strong) QSRecord *record;

@end
