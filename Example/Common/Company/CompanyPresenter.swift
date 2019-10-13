//
//  CompanyPresenter.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit
import CloudKit
import SyncKit

protocol CompanyPresenter: class {
    func viewDidLoad()
    func didTapSynchronize()
    func didTapInsert()
    func didSelectCompany(at indexPath: IndexPath)
    func delete(at indexPath: IndexPath)
}

class DefaultCompanyPresenter: NSObject, CompanyPresenter {
    
    weak var view: CompanyView?
    let interactor: CompanyInteractor
    let wireframe: CompanyWireframe
    let synchronizer: CloudKitSynchronizer
    let canEdit: Bool
    var companies: [[Company]] = [] {
        didSet {
            let companySections = companies.map {
                CompanySection(companies: $0.map { company in
                    CompanyCellViewModel(name: company.name ?? "Nil name", isSharing: company.isSharing, isSharedWithMe: company.isShared, shareAction: { [weak self] in
                        self?.share(company: company)
                    })
                })
            }
            view?.companySections = companySections
        }
    }
    private var sharingCompany: Company?
    
    init(view: CompanyView, interactor: CompanyInteractor, wireframe: CompanyWireframe, synchronizer: CloudKitSynchronizer, canEdit: Bool) {
        self.view = view
        self.interactor = interactor
        self.wireframe = wireframe
        self.synchronizer = synchronizer
        self.canEdit = canEdit
        super.init()
    }
    
    func viewDidLoad() {
        view?.canEdit = canEdit
        interactor.load()
    }
    
    func didTapSynchronize() {
        view?.showLoading(true)
        synchronizer.synchronize { [weak self](error) in
            self?.view?.showLoading(false)
            if let error = error {
                self?.handle(error)
            } else if let zoneID = self?.synchronizer.modelAdapters.first?.recordZoneID,
                self?.synchronizer.database.databaseScope == CKDatabase.Scope.private {
                self?.synchronizer.subscribeForChanges(in: zoneID, completion: { (error) in
                    if let error = error {
                        debugPrint("Failed to subscribe: \(error.localizedDescription)")
                    } else {
                        debugPrint("Subscribed for notifications")
                    }
                })
            }
        }
    }
    
    func didTapInsert() {
        let alertController = UIAlertController(title: "New company", message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter company name"
        }
        alertController.addAction(UIAlertAction(title: "Add", style: .default, handler: { [interactor](_) in
            interactor.insertCompany(name: alertController.textFields?.first?.text ?? "")
        }))
        view?.present(alertController, animated: true, completion: nil)
    }
    
    func didSelectCompany(at indexPath: IndexPath) {
        let company = companies[indexPath.section][indexPath.row]
        var canEdit = true
        if company.isShared {
            if let share = synchronizer.share(for: interactor.modelObject(for: company)!) {
                canEdit = share.currentUserParticipant?.permission == .readWrite
            } else {
                canEdit = false
            }
        }
        wireframe.show(company: company, canEdit: canEdit)
    }
    
    func delete(at indexPath: IndexPath) {
        interactor.delete(company: companies[indexPath.section][indexPath.row])
    }
    
    func share(company: Company) {
        sharingCompany = company
        
        synchronizer.synchronize { [weak self](error) in
            guard error == nil,
                let strongSelf = self,
                let company = strongSelf.sharingCompany,
                let modelObject = strongSelf.interactor.modelObject(for: company) else { return }
            
            let share = strongSelf.synchronizer.share(for: modelObject)
            let container = CKContainer(identifier: strongSelf.synchronizer.containerIdentifier)
            let sharingController: UICloudSharingController
            if let share = share {
                sharingController = UICloudSharingController(share: share, container: container)
            } else {
                sharingController = UICloudSharingController(preparationHandler: { (controller, completionHandler) in
                    strongSelf.synchronizer.share(object: modelObject,
                                                  publicPermission: .readOnly,
                                                  participants: [],
                                                  completion: { (share, error) in
                                                    share?[CKShare.SystemFieldKey.title] = company.name
                                                    completionHandler(share, container, error)
                    })
                })
            }
            sharingController.availablePermissions = [.allowPublic, .allowReadOnly, .allowReadWrite]
            sharingController.delegate = self
            strongSelf.view?.present(sharingController,
                                     animated: true,
                                     completion: nil)
        }
    }
}

extension DefaultCompanyPresenter: CompanyInteractorDelegate {
    func didUpdateCompanies(_ companies: [[Company]]) {
        DispatchQueue.main.async {
            self.companies = companies
        }
    }
}

extension DefaultCompanyPresenter {
    func handle(_ error: Error) {
        if let nserror = error as NSError?,
            nserror.code == CKError.changeTokenExpired.rawValue {
                //handle
        } else {
            let alertController = UIAlertController(title: "Error",
                                                    message: error.localizedDescription,
                                                    preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            view?.present(alertController, animated: true, completion: nil)
        }
    }
}

extension DefaultCompanyPresenter: UICloudSharingControllerDelegate {
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return sharingCompany?.name ?? ""
    }
    
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        debugPrint("\(error.localizedDescription)")
    }
    
    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        guard let share = csc.share,
            let company = sharingCompany,
            let modelObject = interactor.modelObject(for: company) else { return }
        synchronizer.saveShare(share, for: modelObject)
        interactor.refreshObjects()
    }
    
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        guard let company = sharingCompany,
            let modelObject = interactor.modelObject(for: company) else { return }
        synchronizer.deleteShare(for: modelObject)
        interactor.refreshObjects()
    }
}
