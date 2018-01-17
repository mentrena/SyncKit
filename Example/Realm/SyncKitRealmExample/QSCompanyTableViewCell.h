//
//  QSCompanyTableViewCell.h
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 15/02/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface QSCompanyTableViewCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel *nameLabel;
@property (nonatomic, weak) IBOutlet UIButton *sharingButton;

@property (nonatomic, strong) void (^shareButtonAction)(void);

@end
