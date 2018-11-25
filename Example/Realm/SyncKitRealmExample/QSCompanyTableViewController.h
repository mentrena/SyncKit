//
//  QSCompanyTableViewController.h
//  SyncKitRealm
//
//  Created by Manuel Entrena on 04/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SyncKit/QSCloudKitSynchronizer.h>
#import "AppDelegate.h"

@class RLMRealm;

@interface QSCompanyTableViewController : UITableViewController

@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) QSCloudKitSynchronizer *synchronizer;
@property (nonatomic, weak) AppDelegate *appDelegate;

- (void)setupCompanies;
- (void)stopUsingRealmObjects;

@end

