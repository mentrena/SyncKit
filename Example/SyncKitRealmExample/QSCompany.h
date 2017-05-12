//
//  QSCompany.h
//  SyncKitRealm
//
//  Created by Manuel Entrena on 04/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import <Realm/Realm.h>
#import "QSEmployee.h"

@interface QSCompany : RLMObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSNumber<RLMInt> *sortIndex;
@property (nonatomic, strong) NSString *identifier;

@property (readonly) RLMLinkingObjects *employees;

@end

RLM_ARRAY_TYPE(QSCompany) // define RLMArray<Person
