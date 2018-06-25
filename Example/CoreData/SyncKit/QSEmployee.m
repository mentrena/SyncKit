//
//  QSEmployee.m
//  SyncKit
//
//  Created by Manuel Entrena on 30/12/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import "QSEmployee.h"

@implementation QSEmployee

+ (NSString *)primaryKey
{
    return @"identifier";
}

+ (NSString *)parentKey
{
    return @"company";
}

@end
