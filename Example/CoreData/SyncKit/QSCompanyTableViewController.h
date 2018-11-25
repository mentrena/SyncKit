//
//  QSCompanyTableViewController.h
//  SyncKit
//
//  Created by Manuel Entrena on 31/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SyncKit/QSCloudKitSynchronizer.h>
#import "QSAppDelegate.h"

@interface QSCompanyTableViewController : UITableViewController

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) QSCloudKitSynchronizer *synchronizer;

@property (nonatomic, weak) QSAppDelegate *appDelegate;

@end
