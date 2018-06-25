//
//  QSSharedCompanyTableViewController.m
//  SyncKitRealm
//
//  Created by Manuel Entrena on 04/05/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import "QSSharedCompanyTableViewController.h"
#import "QSEmployeeTableViewController.h"

#import <Realm/Realm.h>

#import "QSCompanyTableViewCell.h"
#import "QSCompany.h"
@import SyncKit;

@interface QSSharedCompanyTableViewController () <UICloudSharingControllerDelegate, QSMultiRealmResultsControllerDelegate>

@property (nonatomic, strong) RLMNotificationToken *notificationToken;

@property (nonatomic, weak) IBOutlet UIButton *syncButton;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *indicatorView;

@property (nonatomic, strong) QSMultiRealmResultsController *resultsController;

@property (nonatomic, strong) QSCompany *sharingCompany;

@end

@implementation QSSharedCompanyTableViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self setupResultsController];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.clearsSelectionOnViewWillAppear = self.splitViewController.isCollapsed;
    
    [self.tableView reloadData];
}

- (void)setupResultsController
{
    if (!_resultsController) {
        _resultsController = [self.synchronizer multiRealmResultsControllerWithClass:[QSCompany class] predicate:nil];
        _resultsController.delegate = self;
    }
}

- (void)multiRealmResultsControllerDidChangeRealms:(QSMultiRealmResultsController *)controller
{
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)didTapSynchronize:(id)sender
{
    [self synchronizeWithCompletion:nil];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showEmployees"]) {
        QSCompany *company = (QSCompany *)sender;
        QSEmployeeTableViewController *controller = (QSEmployeeTableViewController *)segue.destinationViewController;
        controller.realm = company.realm;
        controller.company = company;
        CKShare *share = [self.synchronizer shareFor:company];
        controller.canWrite = share.currentUserParticipant.permission == CKShareParticipantPermissionReadWrite;;
        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
    }
}


#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.resultsController.results.count;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    RLMResults *sectionResults = self.resultsController.results[section];
    return sectionResults.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    QSCompanyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    
    QSCompany *company = [self companyAtIndexPath:indexPath];
    
    cell.nameLabel.text = company.name;
    
    CKShare *share = [self.synchronizer shareFor:company];
    if (share) {
        [cell.sharingButton setTitle:@"Sharing" forState:UIControlStateNormal];
    } else {
        [cell.sharingButton setTitle:@"Share" forState:UIControlStateNormal];
    }
    
    __weak QSSharedCompanyTableViewController *weakSelf = self;
    
    cell.shareButtonAction = ^{
        [weakSelf shareCompany:company];
    };
    
    return cell;
}

- (QSCompany *)companyAtIndexPath:(NSIndexPath *)indexPath
{
    RLMResults *sectionResults = self.resultsController.results[indexPath.section];
    QSCompany *company = sectionResults[indexPath.row];
    return company;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        QSCompany *company = [self companyAtIndexPath:indexPath];
        [company.realm transactionWithBlock:^{
            [company.realm deleteObject:company];
        }];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    QSCompany *company = [self companyAtIndexPath:indexPath];
    [self performSegueWithIdentifier:@"showEmployees" sender:company];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Sync

- (void)synchronizeWithCompletion:(void(^)(NSError *error))completion
{
    [self showLoading:YES];
    __weak QSSharedCompanyTableViewController *weakSelf = self;
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        
        [weakSelf showLoading:NO];
        
        if (error) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error: %@", error] preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            
            [weakSelf presentViewController:alertController animated:YES completion:nil];
        }
        
        [self.tableView reloadData];
        
        if (completion) {
            completion(error);
        }
    }];
}

#pragma mark - Sharing

- (void)shareCompany:(QSCompany *)company
{
    self.sharingCompany = company;
    
    __weak QSSharedCompanyTableViewController *weakSelf = self;
    
    [self synchronizeWithCompletion:^(NSError *error) {
        
        if (!error) {
            UICloudSharingController *sharingController;
            CKShare *share = [weakSelf.synchronizer shareFor:company];
            CKContainer *container = [CKContainer containerWithIdentifier:weakSelf.synchronizer.containerIdentifier];
            if (share) {
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
    [self.synchronizer synchronizeWithCompletion:nil];
}

- (void)cloudSharingControllerDidStopSharing:(UICloudSharingController *)csc
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self synchronizeWithCompletion:nil];
    });
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

@end

