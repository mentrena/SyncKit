//
//  QSCompanyTableViewCell.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 15/02/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

import UIKit

class QSCompanySwiftTableViewCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sharingButton: UIButton!
    var shareButtonAction: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }

    @IBAction func didTapShare(_ sender: Any) {
        if shareButtonAction != nil {
            shareButtonAction?()
        }
    }
}
