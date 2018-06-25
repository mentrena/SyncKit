//
//  QSCompanyTableViewCell.m
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 15/02/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

#import "QSCompanyTableViewCell.h"

@implementation QSCompanyTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)didTapShare:(id)sender
{
    if (self.shareButtonAction) {
        self.shareButtonAction();
    }
}

@end
