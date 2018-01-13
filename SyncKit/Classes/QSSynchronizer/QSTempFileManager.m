//
//  QSTempFileManager.m
//  Pods
//
//  Created by Manuel Entrena on 10/01/2018.
//

#import "QSTempFileManager.h"

@implementation QSTempFileManager

- (NSURL *)assetDirectory
{
    NSURL *directoryURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"com.mentrena.QSTempFileManager"];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([[NSFileManager defaultManager] fileExistsAtPath:[directoryURL path]] == NO) {
            [[NSFileManager defaultManager] createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
    return directoryURL;
}

- (NSURL *)storeData:(NSData *)data
{
    NSString *fileName = [NSProcessInfo processInfo].globallyUniqueString;
    NSURL *url = [[self assetDirectory] URLByAppendingPathComponent:fileName];
    [data writeToURL:url options:NSDataWritingAtomic error:nil];
    return url;
}

- (void)clearTempFiles
{
    NSArray *fileURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self assetDirectory] includingPropertiesForKeys:nil options:0 error:nil];
    for (NSURL *fileURL in fileURLs) {
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    }
}

@end
