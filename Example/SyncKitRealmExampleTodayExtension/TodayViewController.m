//
//  TodayViewController.m
//  SyncKitRealmExampleTodayExtension
//
//  Created by Manuel Entrena on 28/08/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import <Realm/Realm.h>
#import "QSCompany.h"
#import <SyncKit/QSCloudKitSynchronizer+Realm.h>

@interface TodayViewController () <NCWidgetProviding>

@property (nonatomic, weak) IBOutlet UILabel *countLabel;
@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) QSCloudKitSynchronizer *synchronizer;

@end

@implementation TodayViewController

- (void)viewDidLoad {
    /********************************************************************************************************
     To use Extension enable app groups and initialize SyncKit with the right suite name
     *******************************************************************************************************/
    [super viewDidLoad];
    
    [self updateObjectCount];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateObjectCount
{
    RLMResults *results = [QSCompany allObjectsInRealm:self.realm];
    self.countLabel.text = [NSString stringWithFormat:@"%ld", results.count];
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData

    NSLog(@"today extension: widgetPerformUpdate");
    
    [self.synchronizer synchronizeWithCompletion:^(NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error);
            completionHandler(NCUpdateResultFailed);
        } else {
            [self updateObjectCount];
            completionHandler(NCUpdateResultNoData);
        }
    }];
}

- (RLMRealm *)realm
{
    if (!_realm) {
        RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
        configuration.fileURL = [self realmPath];
        _realm = [RLMRealm realmWithConfiguration:configuration error:nil];
    }
    return _realm;
}

- (NSURL *)realmPath
{
    NSURL *groupURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.mentrena.todayextensiontest"];
    return [groupURL URLByAppendingPathComponent:@"realmTest"];
}

- (QSCloudKitSynchronizer *)synchronizer
{
    if (!_synchronizer) {
        _synchronizer = [QSCloudKitSynchronizer cloudKitSynchronizerWithContainerName:@"iCloud.com.mentrena.SyncKitRealmDemo" realmConfiguration:self.realm.configuration suiteName:@"group.com.mentrena.todayextensiontest"];
    }
    return _synchronizer;
}

@end

