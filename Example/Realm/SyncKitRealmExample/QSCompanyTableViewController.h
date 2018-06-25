//
//  QSCompanyTableViewController.h
//  SyncKitRealm
//
//  Created by Manuel Entrena on 04/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SyncKit/QSCloudKitSynchronizer.h>

@class RLMRealm;

@interface QSCompanyTableViewController : UITableViewController

@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) QSCloudKitSynchronizer *synchronizer;


@end

