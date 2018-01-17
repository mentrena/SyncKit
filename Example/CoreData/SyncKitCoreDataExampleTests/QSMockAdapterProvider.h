//
//  QSMockAdapterProvider.h
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 10/05/2018.
//  Copyright © 2018 Manuel Entrena. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SyncKit/QSCloudKitSynchronizer.h>

@interface QSMockAdapterProvider : NSObject <QSCloudKitSynchronizerAdapterProvider>

@property (nonatomic, strong) id<QSModelAdapter> modelAdapterValue;

@property (nonatomic, assign) BOOL modelAdapterForRecordZoneIDCalled;
@property (nonatomic, assign) BOOL zoneWasDeletedWithIDCalled;

@end
