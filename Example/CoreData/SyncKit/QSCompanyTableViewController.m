//
//  QSCompanyTableViewController.m
//  SyncKit
//
//  Created by Manuel Entrena on 31/07/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

#import "QSCompanyTableViewController.h"
#import "QSCompany.h"
#import "QSEmployeeTableViewController.h"
#import "QSCompanyTableViewCell.h"
@import SyncKit;

@interface QSCompanyTableViewController () <NSFetchedResultsControllerDelegate, UICloudSharingControllerDelegate>

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic, weak) IBOutlet UIButton *syncButton;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *indicatorView;

@property (nonatomic, strong) QSCompany *sharingCompany;

@property (nonatomic, weak) IBOutlet UIView *loadingView;

@end

@implementation QSCompanyTableViewController

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
        
        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
        _fetchedResultsController.delegate = self;
        [_fetchedResultsController performFetch:nil];
    }
}

- (void)createCompanyWithName:(NSString *)name
{
    QSCompany *company = [NSEntityDescription insertNewObjectForEntityForName:@"QSCompany" inManagedObjectContext:self.managedObjectContext];
    company.identifier = [[NSUUID UUID] UUIDString];
    company.name = name;
    [self.managedObjectContext save:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"showEmployees"]) {
        QSEmployeeTableViewController *employeeTableViewController = (QSEmployeeTableViewController *)segue.destinationViewController;
        employeeTableViewController.managedObjectContext = self.managedObjectContext;
        employeeTableViewController.company = (QSCompany *)sender;
        employeeTableViewController.canWrite = YES;
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
    QSCompany *company = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [self performSegueWithIdentifier:@"showEmployees" sender:company];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if ([[self.fetchedResultsController sections] count] > 0) {
        id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
        return [sectionInfo numberOfObjects];
    } else
        return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    QSCompanyTableViewCell *cell = (QSCompanyTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"cell"];
    [self configureCell:cell atIndexPath:indexPath];

    return cell;
}

- (void)configureCell:(QSCompanyTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    QSCompany *company = [self.fetchedResultsController objectAtIndexPath:indexPath];
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
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        QSCompany *company = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self.managedObjectContext deleteObject:company];
        [self.managedObjectContext save:nil];
    }
}

#pragma mark - Actions

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

- (IBAction)didTapSynchronize:(id)sender
{
    [self synchronizeWithCompletion:nil];
}

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
        self.loadingView.hidden = NO;
        [self.indicatorView startAnimating];
    } else {
        self.syncButton.hidden = NO;
        self.loadingView.hidden = YES;
        [self.indicatorView stopAnimating];
    }
}

@end
