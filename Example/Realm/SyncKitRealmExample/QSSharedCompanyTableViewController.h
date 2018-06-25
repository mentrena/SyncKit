//
//  QSSharedCompanyTableViewController.h
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 20/04/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SyncKit/QSCloudKitSynchronizer.h>

@class RLMRealm;

@interface QSSharedCompanyTableViewController : UITableViewController

@property (nonatomic, strong) QSCloudKitSynchronizer *synchronizer;

@end
