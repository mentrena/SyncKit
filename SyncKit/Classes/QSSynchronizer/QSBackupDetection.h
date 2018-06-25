//
//  QSBackupDetection.h
//  Pods
//
//  Created by Manuel Entrena on 07/02/2018.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, QSBackupDetectionResult)
{
    QSBackupDetectionResultFirstRun,
    QSBackupDetectionResultRestoredFromBackup,
    QSBackupDetectionResultRegularLaunch
};

@interface QSBackupDetection : NSObject

+ (void)runBackupDetectionWithCompletion:(void(^)(QSBackupDetectionResult result, NSError *error))completion;

@end
