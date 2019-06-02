//
//  SettingsViewController.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 22/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit
import SyncKit

class SettingsViewController: UITableViewController {
    
    var privateSynchronizer: CloudKitSynchronizer!
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            privateSynchronizer.deleteRecordZone(for: privateSynchronizer.modelAdapters.first!) { (error) in
                DispatchQueue.main.async {
                    let message: String
                    if error != nil {
                        message = "There was an error deleting the record zone"
                    } else {
                        message = "Deleted record zone from iCloud"
                    }
                    let alertController = UIAlertController(title: "Delete record zone", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
}
