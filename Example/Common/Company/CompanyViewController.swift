//
//  CompanyViewController.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit

protocol CompanyView: UIViewController {
    var companySections: [CompanySection] { get set }
    func showLoading(_ loading: Bool)
    var canEdit: Bool { get set }
    var showsSync: Bool { get set }
}

class CompanyViewController: UITableViewController, CompanyView {
    
    var presenter: CompanyPresenter!
    
    @IBOutlet weak var syncButton: UIButton?
    @IBOutlet weak var indicatorView: UIActivityIndicatorView?
    @IBOutlet weak var insertButton: UIButton?
    
    var canEdit = false {
        didSet {
            insertButton?.isHidden = !canEdit
        }
    }
    
    var showsSync = true {
        didSet {
            syncButton?.isHidden = !showsSync
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
    }
    
    func showLoading(_ loading: Bool) {
        if loading {
            syncButton?.isHidden = true
            indicatorView?.startAnimating()
        } else {
            syncButton?.isHidden = false
            indicatorView?.stopAnimating()
        }
    }
    
    var companySections: [CompanySection] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    @IBAction func didTapSynchronize(_ sender: UIButton) {
        presenter.didTapSynchronize()
    }
    
    @IBAction func insertNewCompany(_ sender: UIButton) {
        presenter.didTapInsert()
    }
    
    // MARK: - Table View
    override func numberOfSections(in tableView: UITableView) -> Int {
        return companySections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return companySections[section].companies.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let company = companySections[indexPath.section].companies[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "CompanyCell") as! CompanyTableViewCell
        cell.viewModel = company
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        presenter.didSelectCompany(at: indexPath)
    }
    
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        presenter.delete(at: indexPath)
    }
}
