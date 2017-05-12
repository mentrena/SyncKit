//
//  QSRecord.h
//  Pods
//
//  Created by Manuel Entrena on 06/05/2017.
//
//

#import <Realm/Realm.h>

@class QSSyncedEntity;

@interface QSRecord : RLMObject

@property (nullable, nonatomic, strong) NSData *encodedRecord;

@end
