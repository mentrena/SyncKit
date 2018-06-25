//
//  QSSharedCompanyTableViewController.m
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 20/04/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import "QSSharedCompanyTableViewController.h"
#import "QSCompany+CoreDataClass.h"
#import "QSEmployeeTableViewController.h"
#import "QSCompanyTableViewCell.h"
@import SyncKit;

@interface QSSharedCompanyTableViewController () <QSCoreDataMultiFetchedResultsControllerDelegate, UICloudSharingControllerDelegate>

@property (nonatomic, weak) IBOutlet UIButton *syncButton;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *indicatorView;

@property (nonatomic, strong) NSString *sharingCompanyTitle;

@property (nonatomic, strong) QSCoreDataMultiFetchedResultsController *fetchedResultsController;

@end

@implementation QSSharedCompanyTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupFetchedResultsController];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupFetchedResultsController
{
    if (!_fetchedResultsController) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"QSCompany"];
        fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
        
        _fetchedResultsController = [self.synchronizer multiFetchedResultsControllerWithFetchRequest:fetchRequest];
        _fetchedResultsController.delegate = self;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"showEmployees"]) {
        QSEmployeeTableViewController *employeeTableViewController = (QSEmployeeTableViewController *)segue.destinationViewController;
        QSCompany *company = (QSCompany *)sender;
        employeeTableViewController.company = company;
        employeeTableViewController.managedObjectContext = employeeTableViewController.company.managedObjectContext;
        employeeTableViewController.synchronizer = self.synchronizer;
        CKShare *share = [self.synchronizer shareForObjectWithIdentifier:company.identifier];
        employeeTableViewController.canWrite = share.currentUserParticipant.permission == CKShareParticipantPermissionReadWrite;
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
        default:
            break;
    }
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath]
                    atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    QSCompany *company = [self objectAtIndexPath:indexPath];
    [self performSegueWithIdentifier:@"showEmployees" sender:company];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return self.fetchedResultsController.fetchedResultsControllers.count;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    
    return self.fetchedResultsController.fetchedResultsControllers[section].fetchedObjects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    QSCompanyTableViewCell *cell = (QSCompanyTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"cell"];
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

- (void)configureCell:(QSCompanyTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    QSCompany *company = [self objectAtIndexPath:indexPath];
    cell.nameLabel.text = company.name;
    CKShare *share = [self.synchronizer shareForObjectWithIdentifier:company.identifier];
    [cell.sharingButton setTitle:@"Shared with me" forState:UIControlStateNormal];
    
    __weak QSSharedCompanyTableViewController *weakSelf = self;
    
    cell.shareButtonAction = ^{
        [weakSelf shareCompany:company share:share];
    };
}

- (QSCompany *)objectAtIndexPath:(NSIndexPath *)indexPath
{
    return self.fetchedResultsController.fetchedResultsControllers[indexPath.section].fetchedObjects[indexPath.row];
}

#pragma mark - Actions

- (IBAction)synchronize:(id)sender
{
    self.syncButton.hidden = YES;
    [self.indicatorView startAnimating];
    __weak QSSharedCompanyTableViewController *weakSelf = self;
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        weakSelf.syncButton.hidden = NO;
        [weakSelf.indicatorView stopAnimating];
        if (error) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Error: %@", error] preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            
            [weakSelf presentViewController:alertController animated:YES completion:nil];
        }
    }];
}

- (void)shareCompany:(QSCompany *)company share:(CKShare *)share
{
    UICloudSharingController *sharingController;
    self.sharingCompanyTitle = company.name;
    CKContainer *container = [CKContainer containerWithIdentifier:self.synchronizer.containerIdentifier];
    if (share) {
        sharingController = [[UICloudSharingController alloc] initWithShare:share container:container];
    } else {
        sharingController = [[UICloudSharingController alloc] initWithPreparationHandler:^(UICloudSharingController * _Nonnull controller, void (^ _Nonnull preparationCompletionHandler)(CKShare * _Nullable, CKContainer * _Nullable, NSError * _Nullable)) {
            
            [self.synchronizer shareObjectWithIdentifier:company.identifier publicPermission:CKShareParticipantPermissionReadOnly participants:@[] completion:^(CKShare *share, NSError *error) {
                
                preparationCompletionHandler(share, container, error);
            }];
        }];
    }
    
    sharingController.availablePermissions = UICloudSharingPermissionAllowPublic | UICloudSharingPermissionAllowReadOnly;
    sharingController.delegate = self;
    [self presentViewController:sharingController animated:YES completion:nil];
}

#pragma mark - UICloudSharingControllerDelegate

- (NSString *)itemTitleForCloudSharingController:(UICloudSharingController *)csc
{
    return self.sharingCompanyTitle;
}

- (void)cloudSharingController:(UICloudSharingController *)csc failedToSaveShareWithError:(NSError *)error
{
    
}

- (void)cloudSharingControllerDidSaveShare:(UICloudSharingController *)csc
{
    [self.synchronizer synchronizeWithCompletion:nil];
}

- (void)cloudSharingControllerDidStopSharing:(UICloudSharingController *)csc
{
    [self.synchronizer synchronizeWithCompletion:nil];
}

- (void)multiFetchedResultsControllerDidChangeControllers:(QSCoreDataMultiFetchedResultsController *)controller {
    
    [self.tableView reloadData];
}

@end
