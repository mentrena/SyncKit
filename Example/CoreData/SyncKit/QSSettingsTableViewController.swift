//  Converted to Swift 4 by Swiftify v4.1.6781 - https://objectivec2swift.com/
//
//  QSSettingsTableViewController.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 04/05/2018.
//  Copyright © 2018 Manuel. All rights reserved.
//

import SyncKit
import UIKit

class QSSettingsSwiftTableViewController: UITableViewController {
    var privateSynchronizer: QSCloudKitSynchronizer?
    var sharedSynchronizer: QSCloudKitSynchronizer?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Uncomment the following line to preserve selection between presentations.
        // self.clearsSelectionOnViewWillAppear = NO;
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            
            privateSynchronizer?.eraseRemoteAndLocalData(for: (privateSynchronizer?.modelAdapters().first)!, withCompletion: { error in
                DispatchQueue.main.async(execute: {
                    var message: String
                    if error != nil {
                        message = "There was an error erasing data"
                    } else {
                        message = "Erased private data"
                    }
                    let alertController = UIAlertController(title: "Erase", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alertController, animated: true)
                })
            })
        }
    }
}
