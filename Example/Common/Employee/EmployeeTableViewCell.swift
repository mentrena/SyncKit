//
//  EmployeeTableViewCell.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit

class EmployeeTableViewCell: UITableViewCell {
    
    var viewModel: EmployeeCellViewModel? {
        didSet {
            updateWithViewModel()
        }
    }
    
    func updateWithViewModel() {
        guard let viewModel = viewModel else { return }
        textLabel?.text = viewModel.name
        imageView?.image = viewModel.image
    }
}
