//
//  QSPendingRelationship.h
//  Pods
//
//  Created by Manuel Entrena on 09/05/2017.
//
//

#import <Realm/Realm.h>

@class QSSyncedEntity;

@interface QSPendingRelationship : RLMObject

@property (nonatomic, strong) NSString *relationshipName;
@property (nonatomic, strong) NSString *targetIdentifier;
@property (nonatomic, strong) QSSyncedEntity *forSyncedEntity;

@end
