//
//  QSDefaultCoreDataStackProvider.h
//  Pods
//
//  Created by Manuel Entrena on 28/03/2018.
//

#import <Foundation/Foundation.h>
#import "QSCloudKitSynchronizer.h"

@class QSCoreDataAdapter;
@class QSDefaultCoreDataStackProvider;
@class NSManagedObjectModel;

@protocol QSDefaultCoreDataStackProviderDelegate

- (void)provider:(QSDefaultCoreDataStackProvider *)provider didAddAdapter:(QSCoreDataAdapter *)adapter forZoneID:(CKRecordZoneID *)zoneID;
- (void)provider:(QSDefaultCoreDataStackProvider *)provider didRemoveAdapterForZoneID:(CKRecordZoneID *)zoneID;

@end

@interface QSDefaultCoreDataStackProvider : NSObject <QSCloudKitSynchronizerAdapterProvider>

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSMutableDictionary *adapterDictionary;
@property (nonatomic, readonly) NSMutableDictionary *coreDataStacks;

@property (nonatomic, weak) id<QSDefaultCoreDataStackProviderDelegate> delegate;

@property (nonatomic, readonly) NSURL *directoryURL;

- (instancetype)initWithIdentifier:(NSString *)identifier storeType:(NSString *)storeType model:(NSManagedObjectModel *)model;
- (instancetype)initWithIdentifier:(NSString *)identifier storeType:(NSString *)storeType model:(NSManagedObjectModel *)model appGroup:(NSString *)suiteName;

@end
