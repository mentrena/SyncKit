//
//  QSDefaultCoreDataAdapterDelegate.h
//  Pods
//
//  Created by Manuel Entrena on 02/04/2018.
//

#import <Foundation/Foundation.h>
#import "QSCoreDataAdapter.h"

@interface QSDefaultCoreDataAdapterDelegate : NSObject <QSCoreDataAdapterDelegate>

+ (instancetype)sharedInstance;

@end
