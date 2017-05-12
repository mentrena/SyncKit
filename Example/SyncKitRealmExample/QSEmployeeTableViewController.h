//
//  QSEmployeeTableViewController.h
//  SyncKitRealm
//
//  Created by Manuel Entrena on 04/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RLMRealm;
@class QSCompany;

@interface QSEmployeeTableViewController : UITableViewController

@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) QSCompany *company;

@end

