//
//  QSCompanyTableViewController.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 01/09/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import UIKit
import RealmSwift
import SyncKit

class QSCompanyTableViewController: UITableViewController, UICloudSharingControllerDelegate {
    
    var realm: Realm!
    var synchronizer: QSCloudKitSynchronizer!
    weak var appDelegate: AppDelegate!
    
    var notificationToken: NotificationToken!
    
    @IBOutlet weak var syncButton: UIButton?
    @IBOutlet weak var indicatorView: UIActivityIndicatorView?
    
    var companies: Results<QSCompany>?
    
    var sharingCompany: QSCompany?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCompanies()
    }
    
    func setupCompanies() {
        
        companies = realm.objects(QSCompany.self).sorted(byKeyPath: "sortIndex")
        
        notificationToken = companies?.observe({ [weak self] (change) in
            switch change {
            case .error(_):
                
                print("Realm error")
                break
            case .update(_, let deletions, let insertions, let modifications):
                
                self?.tableView.beginUpdates()
                self?.tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self?.tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self?.tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self?.tableView.endUpdates()
                
            default:
                
                self?.tableView.reloadData()
            }
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        clearsSelectionOnViewWillAppear = splitViewController?.isCollapsed ?? true
    }
    
    @IBAction func insertNewCompany() {
        
        let alertController = UIAlertController(title: "New company", message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter company's name"
        }
        alertController.addAction(UIAlertAction(title: "Add", style: .default, handler: { (action) in
            
            self.createCompany(name: alertController.textFields!.first!.text!)
        }))
        
        present(alertController, animated: true, completion: nil)
    }
    
    func createCompany(name: String) {
        
        let company = QSCompany()
        company.name = name
        company.identifier = NSUUID().uuidString
        company.sortIndex.value = companies!.count
        
        realm.beginWrite()
        realm.add(company)
        try! realm.commitWrite()
    }
    
    @IBAction func synchronize() {
        
        synchronize(completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showEmployees" {
            
            let indexPath = tableView.indexPathForSelectedRow!
            let company = self.companies![indexPath.row]
            
            let controller = segue.destination as! QSEmployeeTableViewController
            controller.realm = realm
            controller.company = company
            controller.canWrite = true
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
    }
    
    // MARK : TableView
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return companies?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! CompanyCell
        
        let company = companies![indexPath.row]
        
        cell.nameLabel?.text = company.name
        
        if let _ = synchronizer.share(for: company) {
            cell.sharingButton?.setTitle("Sharing", for: .normal)
        } else {
            cell.sharingButton?.setTitle("Share", for: .normal)
        }
        
        cell.shareButtonAction = { [weak self] in
            self?.shareCompany(company)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            
            let company = companies![indexPath.row]
            try! realm.write {
                realm.delete(company)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let company = companies![indexPath.row]
        performSegue(withIdentifier: "showEmployees", sender: company)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Sync
    
    func synchronize(completion: ((Error?)->())?) {
        
        showLoading(true)
        synchronizer.synchronize { [weak self] (error) in
            
            self?.showLoading(false)
            
            if let error = error {
                
                if (error as NSError).code == CKError.changeTokenExpired.rawValue {
                    self?.appDelegate.didGetChangeTokenExpiredError()
                } else {
                    let alertController = UIAlertController(title: "Error", message: "Error: \(error.localizedDescription)", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    
                    self?.present(alertController, animated: true, completion: nil)
                }
                
            } else {
                
                self?.tableView.reloadData()
                if let zoneID = self?.synchronizer.modelAdapters().first?.recordZoneID() {
                    self?.synchronizer.subscribeForChanges(in: zoneID, completion: { (error) in
                        if let error = error {
                            print("Failed to subscribe with error: \(error.localizedDescription)")
                        } else {
                            print("Subscribed for notifications")
                        }
                    })
                }
            }
            
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
                    share[CKShare.SystemFieldKey.title] = company.name as NSString?
                    sharingController = UICloudSharingController(share: share, container: container)
                } else {
                    sharingController = UICloudSharingController(preparationHandler: { (controller, handler) in
                        
                        strongSelf.synchronizer.share(object: company,
                                                      publicPermission: .readOnly,
                                                      participants: [],
                                                      completion: { (share, error) in
                                                        
                                                        share?[CKShare.SystemFieldKey.title] = company.name as NSString?
                                                        handler(share, container, error)
                        })
                    })
                }
                
                sharingController.availablePermissions = [.allowPublic, .allowReadOnly, .allowReadWrite]
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
        tableView.reloadData()
    }
    
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        
        guard let company = sharingCompany else {
            return
        }
        
        synchronizer.deleteShare(for: company)
        tableView.reloadData()
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
    
    // MARK: - Resetting
    
    func stopUsingRealmObjects() {
        notificationToken.invalidate()
        sharingCompany = nil
        companies = nil
        tableView.reloadData()
    }
    
}
