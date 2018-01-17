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

@interface QSEmployeeTableViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) RLMResults<QSEmployee *> *employees;
@property (nonatomic, strong) RLMNotificationToken *notificationToken;

@property (nonatomic, strong) QSEmployee *editingEmployee;
@property (nonatomic, weak) IBOutlet UIButton *addButton;

@end

@implementation QSEmployeeTableViewController


- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.addButton.hidden = !self.canWrite;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (RLMResults<QSEmployee *> *)employees
{
    if (!_employees) {
        _employees = [[QSEmployee objectsInRealm:self.realm where:@"company == %@", self.company] sortedResultsUsingKeyPath:@"sortIndex" ascending:YES];
        
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
    cell.textLabel.text = employee.name ?: @"Object name is nil";
    cell.imageView.image = employee.photo ? [UIImage imageWithData:employee.photo] : nil;
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.canWrite;
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.canWrite) {
        [self showReadOnlyPermission];
        return;
    }
    
    QSEmployee *employee = [self.employees objectAtIndex:indexPath.row];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Update employee" message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Add photo" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        [self presentImagePickerForEmployee:employee];
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Clear photo" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.realm transactionWithBlock:^{
            employee.photo = nil;
        }];
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Clear name" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.realm beginWriteTransaction];
        employee.name = nil;
        [self.realm commitWriteTransaction];
    }]];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Enter new name";
    }];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.realm beginWriteTransaction];
        employee.name = alertController.textFields.firstObject.text;
        [self.realm commitWriteTransaction];
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Image

- (void)presentImagePickerForEmployee:(QSEmployee *)employee
{
    self.editingEmployee = employee;
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePickerController.delegate = self;
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    UIImage *image = info[@"UIImagePickerControllerOriginalImage"];
    
    UIImage *resizedImage = [self imageWithImage:image scaledToSize:CGSizeMake(150, 150)];
    
    [self.realm transactionWithBlock:^{
        self.editingEmployee.photo = UIImagePNGRepresentation(resizedImage);
    }];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize
{
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
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
    QSEmployee *employee = [[QSEmployee alloc] init];
    employee.name = name;
    employee.company = self.company;
    employee.identifier = [[NSUUID UUID] UUIDString];
    [self.realm beginWriteTransaction];
    [self.realm addObject:employee];
    [self.realm commitWriteTransaction];
}

- (void)showReadOnlyPermission
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Read only" message:@"You only have read permission for this employee" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}


@end
