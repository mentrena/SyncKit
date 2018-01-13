//
//  QSEmployeeTableViewController.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 01/09/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import UIKit
import RealmSwift

class QSEmployeeTableViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var realm: Realm?
    var company: QSCompany?
    
    var employees: Results<QSEmployee>!
    var notificationToken: NotificationToken?
    
    var editingEmployee: QSEmployee?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let predicate = NSPredicate(format: "company == %@", company!)
        employees = realm!.objects(QSEmployee.self).filter(predicate).sorted(byKeyPath: "sortIndex")
        
        notificationToken = employees?.observe({ [weak self] (change) in
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
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return employees.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        let employee = employees[indexPath.row]
        cell.textLabel?.text = employee.name
        if let photoData = employee.photo {
            cell.imageView?.image = UIImage(data: photoData)
        } else {
            cell.imageView?.image = nil
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            
            let employee = employees[indexPath.row]
            try? realm?.write {
                realm?.delete(employee)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let employee = employees[indexPath.row]
        
        let alertController = UIAlertController(title: "Update employee", message: nil, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Add photo", style: .default, handler: { (action) in
            self.presentImagePickerFor(employee: employee)
        }))
        
        alertController.addAction(UIAlertAction(title: "Clear photo", style: .default, handler: { (action) in
            try? self.realm?.write {
                employee.photo = nil
            }
        }))
        
        alertController.addAction(UIAlertAction(title: "Clear name", style: .default, handler: { (_) in
            self.realm?.beginWrite()
            employee.name = nil
            try! self.realm?.commitWrite()
        }))
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter new name"
        }
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
            self.realm?.beginWrite()
            employee.name = alertController.textFields!.first!.text
            try! self.realm?.commitWrite()
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func insertNewEmployee() {
        
        let alertController = UIAlertController(title: "New employee", message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter employee's name"
        }
        alertController.addAction(UIAlertAction(title: "Add", style: .default, handler: { (_) in
            self.createNewEmployee(name: alertController.textFields!.first!.text!)
        }))
        present(alertController, animated: true, completion: nil)
    }
    
    func createNewEmployee(name: String) {
        
        let employee = QSEmployee()
        employee.name = name
        employee.company = company!
        employee.identifier = NSUUID().uuidString
        employee.sortIndex.value = employees.count
        
        realm?.beginWrite()
        realm?.add(employee)
        try? realm?.commitWrite()
    }
    
    //MARK: - Image
    
    func presentImagePickerFor(employee: QSEmployee) {
        
        editingEmployee = employee
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        
        present(imagePickerController, animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        defer {
            dismiss(animated: true, completion: nil)
        }
        
        guard let image = info["UIImagePickerControllerOriginalImage"] as? UIImage,
        let employee = editingEmployee else {
            return
        }
        
        let resizedImage = self.image(with: image, scaledToSize: CGSize(width: 150, height: 150))
        
        try? realm?.write {
            employee.photo = UIImagePNGRepresentation(resizedImage);
        }
    }
    
    func image(with image: UIImage, scaledToSize newSize: CGSize) -> UIImage {
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    
}
