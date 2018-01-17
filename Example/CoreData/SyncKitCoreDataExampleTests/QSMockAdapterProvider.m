//
//  QSMockAdapterProvider.m
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 10/05/2018.
//  Copyright © 2018 Manuel Entrena. All rights reserved.
//

#import "QSMockAdapterProvider.h"

@implementation QSMockAdapterProvider

- (id<QSModelAdapter>)cloudKitSynchronizer:(QSCloudKitSynchronizer *)synchronizer modelAdapterForRecordZoneID:(CKRecordZoneID *)recordZoneID
{
    self.modelAdapterForRecordZoneIDCalled = YES;
    return self.modelAdapterValue;
}

- (void)cloudKitSynchronizer:(QSCloudKitSynchronizer *)synchronizer zoneWasDeletedWithZoneID:(CKRecordZoneID *)recordZoneID
{
    self.zoneWasDeletedWithIDCalled = YES;
}

@end
