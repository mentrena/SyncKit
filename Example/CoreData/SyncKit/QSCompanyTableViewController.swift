//
//  QSCompanyTableViewController.swift
//  SyncKitCoreDataExample
//
//  Created by Jérôme Haegeli on 24.07.18.
//  Copyright © 2018 Manuel. All rights reserved.
//

import UIKit
import SyncKit

class QSCompanyTableViewController: UITableViewController, NSFetchedResultsControllerDelegate, UICloudSharingControllerDelegate {
    
    var managedObjectContext: NSManagedObjectContext?
    var synchronizer: QSCloudKitSynchronizer?
    
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    var sharingCompany: QSCompany!
    
    @IBOutlet weak var loadingView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        managedObjectContext = CoreDataStack.shared.persistentContainer.viewContext
        synchronizer = CoreDataStack.shared.synchronizer
        setupFetchedResultsController()
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
            fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
            fetchedResultsController?.delegate = self
            try? fetchedResultsController?.performFetch()
            let array = try? managedObjectContext?.fetch(fetchRequest)
        }
    }


    func createCompanyWithName(name: String) {
        
        let company = QSCompany(context: self.managedObjectContext!)
            company.identifier = UUID().uuidString
            company.name = name
            do {
                try self.managedObjectContext?.save()
            } catch {
                print(error)
            }
        
     }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showEmployees" {
           
            guard let employeeTableViewController = segue.destination as? QSEmployeeTableViewController else {
                    fatalError("Application storyboard mis-configuration")
                }
            
            let company = sender as? QSCompany
            employeeTableViewController.company = company
            employeeTableViewController.managedObjectContext = self.managedObjectContext
            employeeTableViewController.canWrite = true
        }
    }
    
//pragma mark - NSFetchedResultsControllerDelegate
  
    
     func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
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
                configureCell(cell: tableView?.cellForRow(at: aPath) as! QSCompanySwiftTableViewCell, atIndexPath: indexPath!)
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
        let company = fetchedResultsController?.object(at: indexPath) as? QSCompany
        performSegue(withIdentifier: "showEmployees", sender: company)
    }

    
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if let frc = fetchedResultsController {
            return frc.sections!.count
        }
        return 0
    }

    override func tableView(_ table: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (fetchedResultsController?.sections?.count)! > 0 {
            let sectionInfo = fetchedResultsController?.sections![section]
            return sectionInfo!.numberOfObjects
        } else {
            return 0
        }
    }

   
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! QSCompanySwiftTableViewCell

        // Configure the cell...

        configureCell(cell: cell, atIndexPath: indexPath)
        return cell
    }
    
    func configureCell(cell: QSCompanySwiftTableViewCell, atIndexPath indexPath: IndexPath) {
        
        let company = self.fetchedResultsController?.object(at: indexPath) as! QSCompany
        cell.nameLabel.text = company.name
        let share = self.synchronizer?.share(for: company)
        if (share != nil) {
            cell.sharingButton.setTitle("Sharing", for: .normal)
        } else {
            cell.sharingButton.setTitle("Share", for: .normal)
        }
        
        cell.shareButtonAction = {
            self.shareCompany(company)
        }

    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let company = fetchedResultsController?.object(at: indexPath) as? QSCompany
            if let aCompany = company {
                managedObjectContext?.delete(aCompany)
            }
            try? managedObjectContext?.save()
        }
    }


//pragma mark - Actions
  
    @IBAction func insertNewCompany(_ sender: Any) {
        let alertController = UIAlertController(title: "New company", message: nil, preferredStyle: .alert)
        alertController.addTextField(configurationHandler: { textField in
            textField.placeholder = "Enter company's name"
        })
        alertController.addAction(UIAlertAction(title: "Add", style: .default, handler: { action in
            self.createCompanyWithName(name: (alertController.textFields?.first?.text)!)
        }))
        present(alertController, animated: true)
    }


    @IBAction func didTapSynchronize(_ sender: Any) {
        synchronize(withCompletion: nil)
    }

    
    func synchronize(withCompletion completion: ((_ error: Error?) -> Void)? = nil) {
        showLoading(true)
        print("synchronize called")
        self.synchronizer?.synchronize(completion: { error in
            self.showLoading(false)
            if error != nil {
                var alertController: UIAlertController? = nil
                if let anError = error {
                    print("Sync Error : \(anError)")
                    alertController = UIAlertController(title: "Sync Error", message: "Error: \(anError)", preferredStyle: .alert)
                }
                alertController?.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                if let aController = alertController {
                    self.present(aController, animated: true)
                }
            } else {
                let zoneID: CKRecordZoneID? = self.synchronizer?.modelAdapters().first?.recordZoneID()
                if zoneID != nil {
                    self.synchronizer?.subscribeForChanges(in: zoneID!) { error in
                        if error != nil {
                            if let anError = error {
                                print("Failed to subscribe with error: \(anError)")
                            }
                        } else {
                            print("Subscribed for notifications")
                        }
                    }
                }
            }
            if (completion != nil) {
                completion!(error)
            }
            
        })
    }
    

    func shareCompany(_ company: QSCompany) {
        sharingCompany = company
        synchronize(withCompletion: { error in
            if error == nil {
                var sharingController: UICloudSharingController?
                let share: CKShare? = self.synchronizer?.share(for: company)
                let container = CKContainer(identifier: (self.synchronizer?.containerIdentifier)! )
                if share != nil {
                    if let aShare = share {
                        sharingController = UICloudSharingController(share: aShare, container: container)
                    }
                } else {
                    sharingController = UICloudSharingController(preparationHandler: { controller, preparationCompletionHandler in
                        self.synchronizer?.share(object: company, publicPermission: CKShareParticipantPermission.readOnly, participants: []) { share, error in
                            if let aName = company.name {
                                share?[CKShareTitleKey] = aName as CKRecordValue
                            }
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

    
    
// pragma mark - UICloudSharingControllerDelegate
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return self.sharingCompany.name
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("Error saving: \(error)")
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        synchronizer?.saveShare(csc.share!, for: sharingCompany)
        tableView.reloadData()
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        synchronizer?.deleteShare(for: sharingCompany)
        tableView.reloadData()
    }

    
//pragma mark - Loading
    
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
