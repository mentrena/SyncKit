//
//  QSNamesTransformer.h
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 18/10/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QSNamesTransformer : NSValueTransformer

+ (BOOL)transformedValueCalled;
+ (BOOL)reverseTransformedValueCalled;
+ (void)resetValues;

@end

NS_ASSUME_NONNULL_END
