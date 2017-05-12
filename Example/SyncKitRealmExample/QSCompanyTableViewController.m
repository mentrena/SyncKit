//
//  QSCompanyTableViewController.m
//  SyncKitRealm
//
//  Created by Manuel Entrena on 04/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import "QSCompanyTableViewController.h"
#import "QSEmployeeTableViewController.h"

#import <Realm/Realm.h>

#import "QSCompany.h"
#import <SyncKit/QSRealmChangeManager.h>

@interface QSCompanyTableViewController ()

@property (nonatomic, strong) RLMResults<QSCompany *> *companies;

@property (nonatomic, strong) RLMNotificationToken *notificationToken;

@property (nonatomic, weak) IBOutlet UIButton *syncButton;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *indicatorView;

@end

@implementation QSCompanyTableViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (RLMResults<QSCompany *> *)companies
{
    if (!_companies) {
        _companies = [[QSCompany allObjects] sortedResultsUsingKeyPath:@"sortIndex" ascending:YES];
        
        __weak QSCompanyTableViewController *weakSelf = self;
        self.notificationToken = [_companies addNotificationBlock:^(RLMResults<QSCompany *> *results, RLMCollectionChange *changes, NSError *error) {
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
    
    return _companies;
}

- (void)viewWillAppear:(BOOL)animated {
    self.clearsSelectionOnViewWillAppear = self.splitViewController.isCollapsed;
    [super viewWillAppear:animated];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)insertNewCompany:(id)sender
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"New company" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Enter company's name";
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self createCompanyWithName:alertController.textFields.firstObject.text];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)createCompanyWithName:(NSString *)name
{
    QSCompany *newCompany = [[QSCompany alloc] init];
    newCompany.name = name;
    newCompany.identifier = [[NSUUID UUID] UUIDString];
    newCompany.sortIndex = @(self.companies.count);
    
    [self.realm beginWriteTransaction];
    [self.realm addObject:newCompany];
    [self.realm commitWriteTransaction];
}

- (IBAction)synchronize:(id)sender
{
    self.syncButton.hidden = YES;
    [self.indicatorView startAnimating];
    __weak QSCompanyTableViewController *weakSelf = self;
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        weakSelf.syncButton.hidden = NO;
        [weakSelf.indicatorView stopAnimating];
        if (error) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error: %@", error] preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alertController animated:YES completion:nil];
        }
    }];
}

- (IBAction)clearAll:(id)sender
{
    [self.synchronizer eraseRemoteAndLocalDataWithCompletion:^(NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error);
        } else {
            //Clear all local data
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.realm beginWriteTransaction];
                for (QSCompany *company in self.companies) {
                    [self.realm deleteObject:company];
                }
                for (QSEmployee *employee in [QSEmployee allObjectsInRealm:self.realm]) {
                    [self.realm deleteObject:employee];
                }
                [self.realm commitWriteTransaction];
            });
        }
    }];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showEmployees"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        QSCompany *company = self.companies[indexPath.row];
        QSEmployeeTableViewController *controller = (QSEmployeeTableViewController *)segue.destinationViewController;
        controller.realm = self.realm;
        controller.company = company;
        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
    }
}


#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.companies.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];

    QSCompany *company = self.companies[indexPath.row];
    
    cell.textLabel.text = company.name;
    return cell;
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        QSCompany *company = [self.companies objectAtIndex:indexPath.row];
        [self.realm transactionWithBlock:^{
            [self.realm deleteObject:company];
        }];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    QSCompany *company = [self.companies objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:@"showEmployees" sender:company];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
