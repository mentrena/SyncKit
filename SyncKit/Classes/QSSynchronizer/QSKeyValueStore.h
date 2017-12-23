//
//  QSKeyValueStore.h
//  Pods
//
//  Created by Manuel Entrena on 22/12/2017.
//

#import <Foundation/Foundation.h>

@protocol QSKeyValueStore <NSObject>

- (id)objectForKey:(NSString *)defaultName;
- (void)setObject:(id)value forKey:(NSString *)defaultName;
- (BOOL)boolForKey:(NSString *)defaultName;
- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;
- (void)removeObjectForKey:(NSString *)defaultName;

@end

@interface NSUserDefaults (QSKeyValueStore) <QSKeyValueStore>
@end
