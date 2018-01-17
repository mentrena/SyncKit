//
//  QSSettingsTableViewController.h
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 04/05/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import <UIKit/UIKit.h>
@import SyncKit;

@interface QSSettingsTableViewController : UITableViewController

@property (nonatomic, strong) QSCloudKitSynchronizer *privateSynchronizer;
@property (nonatomic, strong) QSCloudKitSynchronizer *sharedSynchronizer;

@end
