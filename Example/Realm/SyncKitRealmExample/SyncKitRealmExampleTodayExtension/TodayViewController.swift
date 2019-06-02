//
//  TodayViewController.swift
//  SyncKitRealmExampleTodayExtension
//
//  Created by Manuel Entrena on 29/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit
import NotificationCenter
import Realm
import SyncKit

class TodayViewController: UIViewController, NCWidgetProviding {
    
    @IBOutlet weak var countLabel: UILabel!
    lazy var realm: RLMRealm = {
        let configuration = RLMRealmConfiguration()
        configuration.fileURL = self.realmPath
        return try! RLMRealm(configuration: configuration)
    }()
    lazy var synchronizer: CloudKitSynchronizer = {
        return CloudKitSynchronizer.privateSynchronizer(containerName: "iCloud.com.mentrena.SyncKitRealmExample", configuration: self.realm.configuration, suiteName: "group.com.mentrena.todayextensiontest")
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        updateObjectCount()
    }
    
    func updateObjectCount() {
        let results = QSCompany.allObjects(in: realm)
        countLabel.text = "\(results.count)"
    }
        
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        debugPrint("Today Extension: widgetPerformUpdate")
        
        synchronizer.synchronize { (error) in
            if let error = error {
                debugPrint("Error: \(error.localizedDescription)")
                completionHandler(.failed)
            } else {
                self.updateObjectCount()
                completionHandler(.noData)
            }
        }
    }
    
    var realmPath: URL {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mentrena.todayextensiontest")!.appendingPathComponent("realmTest")
    }
}
