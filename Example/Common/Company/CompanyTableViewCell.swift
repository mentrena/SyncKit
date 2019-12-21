//
//  CompanyTableViewCell.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit

class CompanyTableViewCell: UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel?
    @IBOutlet weak var shareButton: UIButton?
    
    var viewModel: CompanyCellViewModel? {
        didSet {
            updateWithViewModel()
        }
    }
    
    func updateWithViewModel() {
        guard let viewModel = viewModel else { return }
        
        nameLabel?.text = viewModel.name
        if viewModel.isSharedWithMe {
            shareButton?.setTitle("Shared with me", for: .normal)
        } else {
            shareButton?.setTitle(viewModel.isSharing ? "Sharing" : "Share", for: .normal)
        }
        shareButton?.isHidden = !viewModel.showShareStatus
    }
    
    @IBAction func didTapShare() {
        viewModel?.shareAction?()
    }
}
