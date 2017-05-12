//
//  SyncKitLog.h
//  SyncKitOSX
//
//  Created by Manuel Entrena on 06/08/2016.
//  Copyright © 2016 mentrena. All rights reserved.
//

#ifndef SyncKitLog_h
#define SyncKitLog_h

#ifdef DEBUG
#define DLog( s, ... ) NSLog( @"<%p %@:(%d)> %@", self, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define DLog( s, ... )
#endif

#endif /* SyncKitLog_h */
