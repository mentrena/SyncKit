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

#import "QSCompanyTableViewCell.h"
#import "QSCompany.h"
@import SyncKit;

@interface QSCompanyTableViewController () <UICloudSharingControllerDelegate>

@property (nonatomic, strong) RLMResults<QSCompany *> *companies;

@property (nonatomic, strong) RLMNotificationToken *notificationToken;

@property (nonatomic, weak) IBOutlet UIButton *syncButton;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *indicatorView;

@property (nonatomic, strong) QSCompany *sharingCompany;

@end

@implementation QSCompanyTableViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setupCompanies];
}

- (void)setupCompanies
{
    self.companies = [[QSCompany allObjectsInRealm:self.realm] sortedResultsUsingKeyPath:@"sortIndex" ascending:YES];
    
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

- (IBAction)didTapSynchronize:(id)sender
{
    [self synchronizeWithCompletion:nil];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showEmployees"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        QSCompany *company = self.companies[indexPath.row];
        QSEmployeeTableViewController *controller = (QSEmployeeTableViewController *)segue.destinationViewController;
        controller.realm = self.realm;
        controller.company = company;
        controller.canWrite = YES;
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
    QSCompanyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];

    QSCompany *company = self.companies[indexPath.row];
    
    cell.nameLabel.text = company.name;
    
    CKShare *share = [self.synchronizer shareFor:company];
    if (share) {
        [cell.sharingButton setTitle:@"Sharing" forState:UIControlStateNormal];
    } else {
        [cell.sharingButton setTitle:@"Share" forState:UIControlStateNormal];
    }
    
    __weak QSCompanyTableViewController *weakSelf = self;
    
    cell.shareButtonAction = ^{
        [weakSelf shareCompany:company];
    };
    
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
            for (QSEmployee *employee in company.employees) {
                [self.realm deleteObject:employee];
            }
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

#pragma mark - Sync

- (void)synchronizeWithCompletion:(void(^)(NSError *error))completion
{
    [self showLoading:YES];
    __weak QSCompanyTableViewController *weakSelf = self;
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        
        [weakSelf showLoading:NO];
        
        if (error) {
            
            if (error.code == CKErrorChangeTokenExpired) {
                [self.appDelegate didGetChangeTokenExpiredError];
            } else {
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error: %@", error] preferredStyle:UIAlertControllerStyleAlert];
                
                [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                
                [weakSelf presentViewController:alertController animated:YES completion:nil];
            }
        } else {
            [self.tableView reloadData];
            CKRecordZoneID *zoneID = weakSelf.synchronizer.modelAdapters.firstObject.recordZoneID;
            if (zoneID) {
                [weakSelf.synchronizer subscribeForChangesIn:zoneID completion:^(NSError *error) {
                    if (error) {
                        NSLog(@"Failed to subscribe with error: %@", error);
                    } else {
                        NSLog(@"Subscribed for notifications");
                    }
                }];
            }
        }
        if (completion) {
            completion(error);
        }
    }];
}

#pragma mark - Sharing

- (void)shareCompany:(QSCompany *)company
{
    self.sharingCompany = company;
    
    __weak QSCompanyTableViewController *weakSelf = self;
    
    [self synchronizeWithCompletion:^(NSError *error) {
        
        if (!error) {
            UICloudSharingController *sharingController;
            CKShare *share = [weakSelf.synchronizer shareFor:company];
            CKContainer *container = [CKContainer containerWithIdentifier:weakSelf.synchronizer.containerIdentifier];
            if (share) {
                share[CKShareTitleKey] = company.name;
                sharingController = [[UICloudSharingController alloc] initWithShare:share container:container];
            } else {
                sharingController = [[UICloudSharingController alloc] initWithPreparationHandler:^(UICloudSharingController * _Nonnull controller, void (^ _Nonnull preparationCompletionHandler)(CKShare * _Nullable, CKContainer * _Nullable, NSError * _Nullable)) {
                    
                    [self.synchronizer shareWithObject:company publicPermission:CKShareParticipantPermissionReadOnly participants:@[] completion:^(CKShare *share, NSError *error) {
                        
                        share[CKShareTitleKey] = company.name;
                        preparationCompletionHandler(share, container, error);
                    }];
                }];
            }
            
            sharingController.availablePermissions = UICloudSharingPermissionAllowPublic | UICloudSharingPermissionAllowReadOnly | UICloudSharingPermissionAllowReadWrite;
            sharingController.delegate = self;
            [weakSelf presentViewController:sharingController animated:YES completion:nil];
        }
    }];
}

#pragma mark - UICloudSharingControllerDelegate

- (NSString *)itemTitleForCloudSharingController:(UICloudSharingController *)csc
{
    return self.sharingCompany.name;
}

- (void)cloudSharingController:(UICloudSharingController *)csc failedToSaveShareWithError:(NSError *)error
{
    NSLog(@"Error saving: %@", error);
}

- (void)cloudSharingControllerDidSaveShare:(UICloudSharingController *)csc
{
    [self.synchronizer saveShare:csc.share for:self.sharingCompany];
    [self.tableView reloadData];
}

- (void)cloudSharingControllerDidStopSharing:(UICloudSharingController *)csc
{
    [self.synchronizer deleteShareFor:self.sharingCompany];
    [self.tableView reloadData];
}

#pragma mark - Loading

- (void)showLoading:(BOOL)loading
{
    if (loading) {
        self.syncButton.hidden = YES;
        [self.indicatorView startAnimating];
    } else {
        self.syncButton.hidden = NO;
        [self.indicatorView stopAnimating];
    }
}

#pragma mark - Resetting

- (void)stopUsingRealmObjects
{
    [self.notificationToken invalidate];
    self.sharingCompany = nil;
    self.companies = nil;
    [self.tableView reloadData];
}

@end
