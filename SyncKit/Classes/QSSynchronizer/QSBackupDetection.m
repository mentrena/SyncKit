//
//  QSBackupDetection.m
//  Pods
//
//  Created by Manuel Entrena on 07/02/2018.
//

#import "QSBackupDetection.h"

NSString * const QSBackupDetectionStoreKey = @"QSBackupDetectionStoreKey";

@implementation QSBackupDetection

+ (NSString *)applicationDocumentsDirectory
{
#if TARGET_OS_IPHONE
    return [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask,YES) lastObject];
#else
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    return [[[urls lastObject] URLByAppendingPathComponent:@"com.mentrena.QSCloudKitSynchronizer"] path];
#endif
}

+ (NSString *)backupDetectionFilePath
{
    return [NSString pathWithComponents:@[[self applicationDocumentsDirectory], @"backupDetection"]];
}

+ (void)runBackupDetectionWithCompletion:(void(^)(QSBackupDetectionResult result, NSError *error))completion
{
    QSBackupDetectionResult result;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self backupDetectionFilePath]]) {
        result = QSBackupDetectionResultRegularLaunch;
    } else {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:QSBackupDetectionStoreKey]) {
            result = QSBackupDetectionResultRestoredFromBackup;
        } else {
            result = QSBackupDetectionResultFirstRun;
        }
    }
    
    NSError *error = nil;
    
    if (result == QSBackupDetectionResultFirstRun || result == QSBackupDetectionResultRestoredFromBackup) {
        // set up detection
        NSString *content = @"Backup detection file\n";
        NSData *fileContents = [content dataUsingEncoding:NSUTF8StringEncoding];
        [[NSFileManager defaultManager] createFileAtPath:[self backupDetectionFilePath] contents:fileContents attributes:nil];
        NSURL *fileURL = [NSURL fileURLWithPath:[self backupDetectionFilePath]];
        [fileURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error];
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:QSBackupDetectionStoreKey];
    }
    
    completion(result, error);
}

@end
