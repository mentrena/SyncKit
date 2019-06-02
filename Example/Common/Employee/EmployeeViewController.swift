//
//  EmployeeViewController.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit

protocol EmployeeView: UIViewController {
    var canWrite: Bool { get set }
    var employees: [EmployeeCellViewModel] { get set }
}

class EmployeeViewController: UITableViewController, EmployeeView {
    
    var presenter: EmployeePresenter!
    var canWrite: Bool = false {
        didSet {
            createNewButton?.isHidden = !canWrite
        }
    }
    
    @IBOutlet weak var createNewButton: UIButton?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
    }
    
    @IBAction func insertNewEmployee(_ sender: UIButton) {
        presenter.didTapInsert()
    }
    
    var employees: [EmployeeCellViewModel] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return employees.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EmployeeCell") as! EmployeeTableViewCell
        cell.viewModel = employees[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return canWrite
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        presenter.delete(at: indexPath.row)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        presenter.didSelectEmployee(at: indexPath.row)
    }
}
