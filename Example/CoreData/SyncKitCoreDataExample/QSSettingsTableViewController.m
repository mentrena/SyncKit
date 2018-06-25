//
//  QSSettingsTableViewController.m
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 04/05/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import "QSSettingsTableViewController.h"

@interface QSSettingsTableViewController ()

@end

@implementation QSSettingsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        
        [self.privateSynchronizer eraseRemoteAndLocalDataForChangeManager:self.privateSynchronizer.changeManagers.firstObject withCompletion:^(NSError *error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *message;
                if (error) {
                    message = @"There was an error erasing data";
                } else {
                    message = @"Erased private data";
                }
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Erase" message:message preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alertController animated:YES completion:nil];
            });
        }];
    }
}

@end
