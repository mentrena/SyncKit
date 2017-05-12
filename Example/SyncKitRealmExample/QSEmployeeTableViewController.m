//
//  QSEmployeeTableViewController.m
//  SyncKitRealm
//
//  Created by Manuel Entrena on 04/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import "QSEmployeeTableViewController.h"
#import <Realm/Realm.h>
#import "QSEmployee.h"
#import "QSCompany.h"

@interface QSEmployeeTableViewController ()

@property (nonatomic, strong) RLMResults<QSEmployee *> *employees;
@property (nonatomic, strong) RLMNotificationToken *notificationToken;

@end

@implementation QSEmployeeTableViewController


- (void)viewDidLoad {
    [super viewDidLoad];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (RLMResults<QSEmployee *> *)employees
{
    if (!_employees) {
        _employees = [[QSEmployee objectsWhere:@"company == %@", self.company] sortedResultsUsingKeyPath:@"sortIndex" ascending:YES];
        
        __weak QSEmployeeTableViewController *weakSelf = self;
        self.notificationToken = [_employees addNotificationBlock:^(RLMResults<QSCompany *> *results, RLMCollectionChange *changes, NSError *error) {
            if (error) {
                NSLog(@"Failed to open Realm on background worker: %@", error);
                return;
            }
            
            UITableView *tableView = weakSelf.tableView;
            // Initial run of the query will pass nil for the change information
            if (!changes) {
                [tableView reloadData];
                return;
            }
            
            // Query results have changed, so apply them to the UITableView
            [tableView beginUpdates];
            [tableView deleteRowsAtIndexPaths:[changes deletionsInSection:0]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            [tableView insertRowsAtIndexPaths:[changes insertionsInSection:0]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            [tableView reloadRowsAtIndexPaths:[changes modificationsInSection:0]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            [tableView endUpdates];
        }];
    }
    
    return _employees;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return self.employees.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    QSEmployee *employee = [self.employees objectAtIndex:indexPath.row];
    cell.textLabel.text = employee.name;
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        QSEmployee *employee = [self.employees objectAtIndex:indexPath.row];
        [self.realm beginWriteTransaction];
        [self.realm deleteObject:employee];
        [self.realm commitWriteTransaction];
    }
}

#pragma mark - Actions

- (IBAction)insertNewEmployee:(id)sender
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"New employee" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Enter employee's name";
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self createEmployeeWithName:alertController.textFields.firstObject.text];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)createEmployeeWithName:(NSString *)name
{
    QSEmployee *employee =[[QSEmployee alloc] init];
    employee.name = name;
    employee.company = self.company;
    employee.identifier = [[NSUUID UUID] UUIDString];
    [self.realm beginWriteTransaction];
    [self.realm addObject:employee];
    [self.realm commitWriteTransaction];
}


@end
