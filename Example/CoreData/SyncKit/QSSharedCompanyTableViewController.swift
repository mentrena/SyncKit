//
//  QSSharedCompanySwiftTableViewController.swift
//  SyncKitCoreDataExample
//
//  Created by Jérôme Haegeli on 25.07.18.
//  Copyright © 2018 Manuel. All rights reserved.
//

import UIKit
import SyncKit

class QSSharedCompanyTableViewController: UITableViewController, QSCoreDataMultiFetchedResultsControllerDelegate, UICloudSharingControllerDelegate {
    
    var synchronizer: QSCloudKitSynchronizer?
    
    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    var sharingCompany: QSCompany!
    var fetchedResultsController: QSCoreDataMultiFetchedResultsController?
    
    @IBOutlet weak var loadingView: UIView?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        subscribeChanges()
        self.setupFetchedResultsController()
    
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.tableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    func setupFetchedResultsController() {
        if !(fetchedResultsController != nil) {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "QSCompany")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            fetchedResultsController = synchronizer?.multiFetchedResultsController(with: fetchRequest)
            fetchedResultsController?.delegate = self
            print(fetchedResultsController)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showEmployees") {
            guard let employeeTableViewController = segue.destination as? QSEmployeeTableViewController else {
                fatalError("Application storyboard mis-configuration")
            }
            
            let company = sender as? QSCompany
            employeeTableViewController.company = company

            if let aContext = employeeTableViewController.company?.managedObjectContext {
                employeeTableViewController.managedObjectContext = aContext
            }
            let share: CKShare? = synchronizer?.share(for: company!)
            employeeTableViewController.canWrite = share?.currentUserParticipant?.permission == .readWrite
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .fade)
        case .delete:
            tableView.deleteSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .fade)
        default:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        let tableView: UITableView? = self.tableView
        switch type {
        case .insert:
            tableView?.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView?.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            if let aPath = indexPath {
                configureCell(tableView?.cellForRow(at: aPath) as? QSCompanySwiftTableViewCell, at: indexPath)
            }
        case .move:
            tableView?.deleteRows(at: [indexPath!], with: .fade)
            tableView?.insertRows(at: [newIndexPath!], with: .fade)
        }
    }

    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let company = object(at: indexPath) as? QSCompany
        performSegue(withIdentifier: "showEmployees", sender: company)
    }
    
// MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        if let frc = fetchedResultsController {
            return frc.fetchedResultsControllers!.count
        }
        return 0
    }
    
    override func tableView(_ table: UITableView, numberOfRowsInSection section: Int) -> Int {
        

        if let frc = fetchedResultsController {
            return frc.fetchedResultsControllers[section].fetchedObjects?.count ?? 0
        }
        return 0
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as? QSCompanySwiftTableViewCell
        configureCell(cell, at: indexPath)
        if let aCell = cell {
            return aCell
        }
        return UITableViewCell()
    }
    
    func configureCell(_ cell: QSCompanySwiftTableViewCell?, at indexPath: IndexPath?) {
        var company: QSCompany? = nil
        if let aPath = indexPath {
            company = object(at: aPath)
        }
        cell?.nameLabel.text = company?.name
        cell?.sharingButton.setTitle("Shared with me", for: .normal)
        cell?.shareButtonAction = {
            self.share(company!)
        }
    }
    
    func object(at indexPath: IndexPath) -> QSCompany {
        if let aRow = fetchedResultsController?.fetchedResultsControllers[indexPath.section].fetchedObjects![indexPath.row] {
            return aRow as! QSCompany
        }
        return QSCompany()
    }

    
    
// MARK: - Actions
    
//    func subscribe() {
//
//        let artistRecordID = CKRecordID(recordName: "Mei Chen")
//        let predicate = NSPredicate(format: "artist = %@", artistRecordID)
//
//        let subscription = CKSubscription(recordType: "Artwork", predicate: predicate, options: .firesOnRecordCreation)
//        let DB = CKContainer.default()
//
//        let CKSubscription = CKRecordZoneSubscription(zoneID: artistRecordID.zoneID)
//        var notificationInfo = CKNotificationInfo()
//        notificationInfo.alertLocalizationKey = "New artwork by your favorite artist."
//        notificationInfo.shouldBadge = true
//
//
//        subscription.notificationInfo = notificationInfo
//
//
//        var publicDatabase: CKDatabase? = CKContainer.default().publicCloudDatabase
//        publicDatabase?.save(subscription, completionHandler: { (subsription, error) in
//            print(error)
//        })
//
//    }
    
    func subscribeChanges() {
        let container = CKContainer.default()
        let subscription = CKDatabaseSubscription(subscriptionID: "test")
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        operation.modifySubscriptionsCompletionBlock = { savedSubscriptions, deletedSubscriptionIDs, operationError in
            if operationError != nil {
                print(operationError)
                return
            } else {
                print("Subscribed")
            }
        }
        
//        container.privateCloudDatabase.add(operation)
        container.sharedCloudDatabase.add(operation)
    }
    
    @IBAction func didTapSynchronize(_ sender: Any) {
        synchronize(withCompletion: { _ in })
    }
    
    func synchronize(withCompletion completion: ((_ error: Error?) -> Void)? = nil) {
        self.showLoading(true)
        synchronizer?.synchronize(completion: { error in
            self.showLoading(false)
            if error != nil {
                var alertController: UIAlertController? = nil
                if let anError = error {
                    alertController = UIAlertController(title: "Error", message: "Error: \(anError)", preferredStyle: .alert)
                }
                alertController?.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                if let aController = alertController {
                    self.present(aController, animated: true)
                }
            }
            
            if (completion != nil) {
                completion!(error)
            }
        })
    }
    
    func share(_ company: QSCompany) {
        sharingCompany = company
        showLoading(true)
        synchronizer?.synchronize(completion: { error in
            self.showLoading(false)
            if error == nil {
                var sharingController: UICloudSharingController?
                let share: CKShare? = self.synchronizer?.share(for: company)
                let container = CKContainer(identifier: self.synchronizer?.containerIdentifier ?? "")
                if share != nil {
                    if let aShare = share {
                        sharingController = UICloudSharingController(share: aShare, container: container)
                    }
                } else {
                    sharingController = UICloudSharingController(preparationHandler: { controller, preparationCompletionHandler in
                        self.synchronizer!.share(object: company, publicPermission: CKShareParticipantPermission.readOnly, participants: []) { share, error in
                            preparationCompletionHandler(share, container, error)
                        }
                    })
                }
                sharingController?.availablePermissions = [.allowPublic, .allowReadOnly, .allowReadWrite]
                sharingController?.delegate = self
                if let aController = sharingController {
                    self.present(aController, animated: true)
                }
            }
        })
    }

    // MARK: - UICloudSharingControllerDelegate
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return sharingCompany?.name
    }
    
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("failed to save share")
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        synchronizer?.saveShare(csc.share!, for: sharingCompany)
        synchronizer?.synchronize(completion: nil)
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(2 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
            self.synchronize(withCompletion: nil)
        })
    }
    
    func multiFetchedResultsControllerDidChangeControllers(_ controller: QSCoreDataMultiFetchedResultsController?) {
        tableView.reloadData()
    }

    // MARK: - Loading
    func showLoading(_ loading: Bool) {
        if loading {
            syncButton.isHidden = true
            loadingView?.isHidden = false
            indicatorView.startAnimating()
        } else {
            syncButton.isHidden = false
            loadingView?.isHidden = true
            indicatorView.stopAnimating()
        }
    }

}
