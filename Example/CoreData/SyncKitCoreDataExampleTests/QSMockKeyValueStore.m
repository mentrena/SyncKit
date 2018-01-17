//
//  QSMockKeyValueStore.m
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 22/12/2017.
//  Copyright © 2017 Manuel. All rights reserved.
//

#import "QSMockKeyValueStore.h"

@interface QSMockKeyValueStore ()

@property (nonatomic, strong) NSMutableDictionary *dictionary;

@end

@implementation QSMockKeyValueStore

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.dictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)objectForKey:(NSString *)defaultName
{
    return [self.dictionary objectForKey:defaultName];
}

- (void)setObject:(id)value forKey:(NSString *)defaultName
{
    [self.dictionary setObject:value forKey:defaultName];
}

- (BOOL)boolForKey:(NSString *)defaultName
{
    return [[self.dictionary objectForKey:defaultName] boolValue];
}

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName
{
    [self.dictionary setObject:@(value) forKey:defaultName];
}

- (void)removeObjectForKey:(NSString *)defaultName
{
    [self.dictionary removeObjectForKey:defaultName];
}

- (void)clear
{
    [self.dictionary removeAllObjects];
}

@end
