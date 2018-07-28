//
//  QSEmployeeSwiftTableViewController.swift
//  SyncKitCoreDataExample
//
//  Created by Jérôme Haegeli on 25.07.18.
//  Copyright © 2018 Manuel. All rights reserved.
//

import UIKit
import CoreData
import UIKit

class QSEmployeeTableViewController: UITableViewController, NSFetchedResultsControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var managedObjectContext: NSManagedObjectContext?
    var company: QSCompany?
    var canWrite = false
    
    private var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
    private var editingEmployee: QSEmployee?
    @IBOutlet private weak var createButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFetchedResultsController()
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        createButton.isHidden = !canWrite
    }
    
    func setupFetchedResultsController() {
        if !(fetchedResultsController != nil) {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "QSEmployee")
            fetchRequest.predicate = NSPredicate(format: "company == %@", company!)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
            fetchedResultsController?.delegate = self
            try? fetchedResultsController?.performFetch()
        }
    }
    
    func createEmployee(withName name: String?) {
        let employee = NSEntityDescription.insertNewObject(forEntityName: "QSEmployee", into: managedObjectContext!) as? QSEmployee
        employee?.name = name
        employee?.company = company
        employee?.identifier = UUID().uuidString
        do {
            try self.managedObjectContext?.save()
        } catch {
            print(error)
        }
    }

//pragma mark - NSFetchedResultsControllerDelegate

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
                configureCell(tableView?.cellForRow(at: aPath), at: indexPath)
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

//pragma mark - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if let sections = fetchedResultsController?.sections {
            return sections.count
        }
        return 0
    }
    
    override func tableView(_ table: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if let sections = fetchedResultsController?.sections {
            let currentSection = sections[section]
            return currentSection.numberOfObjects
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: "cell")
        configureCell(cell, at: indexPath)
        if let aCell = cell {
            return aCell
        }
        return UITableViewCell()
    }
    
    func configureCell(_ cell: UITableViewCell?, at indexPath: IndexPath?) {
        var employee: QSEmployee? = nil
        if let aPath = indexPath {
            employee = fetchedResultsController?.object(at: aPath) as? QSEmployee
        }
        if employee?.photo != nil {
            if let aPhoto = employee?.photo {
                cell?.imageView?.image = UIImage(data: aPhoto as Data)
            }
        } else {
            cell?.imageView?.image = nil
        }
        cell?.textLabel?.text = employee?.name ?? "Object name is nil"
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return canWrite
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let employee = fetchedResultsController?.object(at: indexPath) as? QSEmployee
            if let anEmployee = employee {
                managedObjectContext?.delete(anEmployee)
            }
            try? managedObjectContext?.save()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !canWrite {
            showReadOnlyPermission()
            return
        }
        let employee = fetchedResultsController?.object(at: indexPath) as? QSEmployee
        let alertController = UIAlertController(title: "Update employee", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Add photo", style: .default, handler: { action in
            self.presentImagePicker(for: employee)
        
        }))
        alertController.addAction(UIAlertAction(title: "Clear photo", style: .default, handler: { action in
            employee?.photo = nil
            self.managedObjectContext?.perform({
                try? self.managedObjectContext?.save()
            })
        }))
        alertController.addAction(UIAlertAction(title: "Clear name", style: .default, handler: { action in
            employee?.name = nil
            self.managedObjectContext?.perform({
                try? self.managedObjectContext?.save()
            })
        }))
        alertController.addTextField(configurationHandler: { textField in
            textField.placeholder = "Enter new name"
        })
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { action in
            employee?.name = alertController.textFields?.first?.text
            self.managedObjectContext?.perform({
                try? self.managedObjectContext?.save()
            })
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alertController, animated: true)
    }

    // MARK: - Image
    func presentImagePicker(for employee: QSEmployee?) {
        editingEmployee = employee
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        present(imagePickerController, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let image = info["UIImagePickerControllerOriginalImage"] as? UIImage
        let resizedImage: UIImage? = self.image(with: image, scaledTo: CGSize(width: 150, height: 150))
        editingEmployee?.photo = UIImagePNGRepresentation(resizedImage!) as! NSData
        managedObjectContext?.perform({
            try? self.managedObjectContext?.save()
        })
        dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
    
    func image(with image: UIImage?, scaledTo newSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image?.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func showReadOnlyPermission() {
        let alertController = UIAlertController(title: "Read only", message: "You only have read permission for this employee", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true)
    }
    
    // MARK: - Actions
    @IBAction func insertNewEmployee(_ sender: Any) {
        let alertController = UIAlertController(title: "New employee", message: nil, preferredStyle: .alert)
        alertController.addTextField(configurationHandler: { textField in
            textField.placeholder = "Enter employee's name"
        })
        alertController.addAction(UIAlertAction(title: "Add", style: .default, handler: { action in
            self.createEmployee(withName: alertController.textFields?.first?.text)
        }))
        present(alertController, animated: true)
    }

    
}


