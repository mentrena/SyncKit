//
//  QSEmployee.h
//  SyncKitRealm
//
//  Created by Manuel Entrena on 04/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import <Realm/Realm.h>

@class QSCompany;

@interface QSEmployee : RLMObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSNumber<RLMInt> *sortIndex;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) QSCompany *company;
@property (nonatomic, strong) NSData *photo;

@end

RLM_ARRAY_TYPE(QSEmployee)
