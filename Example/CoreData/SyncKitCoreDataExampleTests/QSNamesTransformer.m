//
//  QSNamesTransformer.m
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 18/10/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import "QSNamesTransformer.h"

static BOOL QSNamesTransformerTransformedValueCalled;
static BOOL QSNamesTransformerReverseTransformedValueCalled;

@implementation QSNamesTransformer

+ (Class)transformedValueClass
{
    return [NSData class];
}

- (id)transformedValue:(id)value
{
    QSNamesTransformerTransformedValueCalled = YES;
    
    return [NSKeyedArchiver archivedDataWithRootObject:value];
}

- (id)reverseTransformedValue:(id)value
{
    QSNamesTransformerReverseTransformedValueCalled = YES;
    
    return [NSKeyedUnarchiver unarchiveObjectWithData:value];
}

+ (BOOL)transformedValueCalled
{
    return QSNamesTransformerTransformedValueCalled;
}

+ (BOOL)reverseTransformedValueCalled
{
    return QSNamesTransformerReverseTransformedValueCalled;
}

+ (void)resetValues
{
    QSNamesTransformerTransformedValueCalled = NO;
    QSNamesTransformerReverseTransformedValueCalled = NO;
}

@end
