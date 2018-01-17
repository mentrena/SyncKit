//
//  QSCompany.m
//  SyncKitRealm
//
//  Created by Manuel Entrena on 04/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import "QSCompany.h"

@implementation QSCompany

+ (NSString *)primaryKey
{
    return @"identifier";
}

+ (NSDictionary *)linkingObjectsProperties
{
    return @{@"employees": [RLMPropertyDescriptor descriptorWithClass:QSEmployee.class propertyName:@"company"]};
}


@end
