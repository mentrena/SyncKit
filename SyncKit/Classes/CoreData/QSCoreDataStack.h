//
//  QSCoreDataStack.h
//  Pods
//
//  Created by Manuel Entrena on 14/07/2016.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface QSCoreDataStack : NSObject

@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;

- (instancetype)initWithStoreType:(NSString *)storeType model:(NSManagedObjectModel *)model storePath:(NSString *)storePath;
- (instancetype)initWithStoreType:(NSString *)storeType model:(NSManagedObjectModel *)model storePath:(NSString *)storePath concurrencyType:(NSManagedObjectContextConcurrencyType)concurrencyType;
- (instancetype)initWithStoreType:(NSString *)storeType model:(NSManagedObjectModel *)model storePath:(NSString *)storePath concurrencyType:(NSManagedObjectContextConcurrencyType)concurrencyType dispatchImmediately:(BOOL)dispatchImmediately;
- (void)deleteStore;

@end
