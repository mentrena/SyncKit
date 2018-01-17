//
//  QSMockModelAdapter.h
//  QSCloudKitSynchronizer
//
//  Created by Manuel Entrena on 23/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SyncKit/QSModelAdapter.h>

@interface QSMockModelAdapter : NSObject <QSModelAdapter>

@property (nonatomic, strong) NSArray *objects;
@property (nonatomic, assign) QSModelAdapterMergePolicy mergePolicy;
@property (nonatomic, strong) CKRecordZoneID *recordZoneIDValue;
@property (nonatomic, strong) NSMutableDictionary *sharesByIdentifier;
@property (nonatomic, strong) NSMutableDictionary *recordsByIdentifier;

- (void)markForUpload:(NSArray *)objects;
- (void)markForDeletion:(NSArray *)objects;

@property (nonatomic, assign) BOOL deleteChangeTrackingCalled;

@end
