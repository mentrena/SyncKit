//
//  QSSharedCompanyTableViewController.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 08/06/2018.
//  Copyright © 2018 Manuel Entrena. All rights reserved.
//

import UIKit
import SyncKit

class QSSharedCompanyTableViewController: UITableViewController, UICloudSharingControllerDelegate {
    
    var synchronizer: QSCloudKitSynchronizer!
    
    var sharingCompany: QSCompany?
    
    var resultsController: MultiRealmResultsController<QSCompany>!
    
    @IBOutlet weak var syncButton: UIButton?
    @IBOutlet weak var indicatorView: UIActivityIndicatorView?
    
    typealias RealmType = QSCompany
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupResultsController()
    }
    
    func setupResultsController() {
        
        resultsController = synchronizer.multiRealmResultsController()
        resultsController.didChangeRealms = { [weak self] controller in
            self?.tableView.reloadData()
        }
    }
    
    @IBAction func didTapSynchronize() {
        
        synchronize(completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showEmployees" {
            
            let company = sender as! QSCompany
            
            let controller = segue.destination as! QSEmployeeTableViewController
            controller.realm = company.realm
            controller.company = company
            let share = synchronizer.share(for: company)
            controller.canWrite = (share?.currentUserParticipant?.permission ?? .readOnly) == .readWrite;
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
    }
    
    // MARK: - TableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return resultsController.results.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let results = resultsController.results[section]
        return results.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! CompanyCell
        
        let company = getCompany(at: indexPath)
        
        cell.nameLabel?.text = company?.name
        
        if let _ = synchronizer.share(for: company!) {
            cell.sharingButton?.setTitle("Sharing", for: .normal)
        } else {
            cell.sharingButton?.setTitle("Share", for: .normal)
        }
        
        cell.shareButtonAction = { [weak self] in
            self?.shareCompany(company!)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            
            let company = getCompany(at: indexPath)
            try! company!.realm?.write {
                company!.realm!.delete(company!)
            }
        }
    }
    
    func getCompany(at indexPath: IndexPath) -> QSCompany! {
        
        let results = resultsController.results[indexPath.section]
        return results[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let company = getCompany(at: indexPath)
        performSegue(withIdentifier: "showEmployees", sender: company)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Sync
    
    func synchronize(completion: ((Error?)->())?) {
        
        showLoading(true)
        synchronizer.synchronize { [weak self] (error) in
            
            self?.showLoading(false)
            
            if let error = error {
                
                let alertController = UIAlertController(title: "Error", message: "Error: \(error.localizedDescription)", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                
                self?.present(alertController, animated: true, completion: nil)
                
            }
            
            self?.tableView.reloadData()
            
            completion?(error)
        }
    }
    
    // MARK: - Sharing
    
    func shareCompany(_ company: QSCompany) {
        
        sharingCompany = company
        
        synchronize { [weak self] (error) in
            if error == nil,
                let strongSelf = self {
                
                let sharingController: UICloudSharingController
                let share = strongSelf.synchronizer.share(for: company)
                let container = CKContainer(identifier: strongSelf.synchronizer.containerIdentifier)
                
                if let share = share {
                    sharingController = UICloudSharingController(share: share, container: container)
                } else {
                    sharingController = UICloudSharingController(preparationHandler: { (controller, handler) in
                        
                        strongSelf.synchronizer.share(object: company,
                                                      publicPermission: .readOnly,
                                                      participants: [],
                                                      completion: { (share, error) in
                                                        
                                                        share?[CKShareTitleKey] = company.name as NSString?
                                                        handler(share, container, error)
                        })
                    })
                }
                
                sharingController.availablePermissions = [.allowPublic, .allowReadOnly, .allowPrivate]
                sharingController.delegate = self
                
                strongSelf.present(sharingController, animated: true, completion: nil)
            }
        }
    }
    
    // MARK : - UICloudSharingControllerDelegate
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        
        return sharingCompany?.name
    }
    
    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        
        guard let company = sharingCompany,
            let share = csc.share else {
                return
        }
        synchronizer.saveShare(share, for: company)
        synchronize(completion: nil)
    }
    
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.synchronize(completion: nil)
        }
    }
    
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        
        print("Failed to save share: \(error.localizedDescription)")
    }
    
    // MARK: - Loading
    
    func showLoading(_ loading: Bool) {
        
        if loading {
            syncButton?.isHidden = true
            indicatorView?.startAnimating()
        } else {
            syncButton?.isHidden = false
            indicatorView?.stopAnimating()
        }
    }
}
