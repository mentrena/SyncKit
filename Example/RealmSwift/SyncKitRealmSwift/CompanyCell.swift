//
//  CompanyCell.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 08/06/2018.
//  Copyright © 2018 Manuel Entrena. All rights reserved.
//

import UIKit

class CompanyCell: UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel?
    @IBOutlet weak var sharingButton: UIButton?
    
    var shareButtonAction: (()->())?
    
    @IBAction func didTapShare() {
        
        shareButtonAction?()
    }
}
