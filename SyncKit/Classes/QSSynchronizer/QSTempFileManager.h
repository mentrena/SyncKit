//
//  QSTempFileManager.h
//  Pods
//
//  Created by Manuel Entrena on 10/01/2018.
//

#import <Foundation/Foundation.h>

@interface QSTempFileManager : NSObject

- (NSURL *)storeData:(NSData *)data;
- (void)clearTempFiles;

@end
