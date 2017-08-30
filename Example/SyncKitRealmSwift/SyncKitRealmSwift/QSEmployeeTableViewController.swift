//
//  QSEmployeeTableViewController.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 01/09/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import UIKit
import RealmSwift

class QSEmployeeTableViewController: UITableViewController {
    
    var realm: Realm?
    var company: QSCompany?
    
    var employees: Results<QSEmployee>!
    var notificationToken: NotificationToken?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let predicate = NSPredicate(format: "company == %@", company!)
        employees = realm!.objects(QSEmployee.self).filter(predicate).sorted(byKeyPath: "sortIndex")
        
        notificationToken = employees?.addNotificationBlock({ [weak self] (change) in
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
        let alertController = UIAlertController(title: "Change name", message: nil, preferredStyle: .alert)
        alertController.addTextField(configurationHandler: nil)
        alertController.addAction(UIAlertAction(title: "Remove name", style: .destructive, handler: { (_) in
            self.realm?.beginWrite()
            employee.name = nil
            try! self.realm?.commitWrite()
        }))
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
    
}
