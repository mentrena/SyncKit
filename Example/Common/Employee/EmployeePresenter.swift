//
//  EmployeePresenter.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import UIKit

protocol EmployeePresenter: class {
    func viewDidLoad()
    func didTapInsert()
    func didSelectEmployee(at index: Int)
    func delete(at index: Int)
}

class DefaultEmployeePresenter: NSObject, EmployeePresenter {
    
    weak var view: EmployeeView!
    let company: Company
    let interactor: EmployeeInteractor
    var editingEmployee: Employee?
    let canEdit: Bool
    var employees: [Employee] = [] {
        didSet {
            let viewModels = employees.map {
                EmployeeCellViewModel(name: $0.name ?? "Nil name",
                                      image: $0.photo != nil ? UIImage(data: $0.photo!) : nil)
            }
            view.employees = viewModels
        }
    }
    
    init(view: EmployeeView, company: Company, interactor: EmployeeInteractor, canEdit: Bool) {
        self.view = view
        self.company = company
        self.interactor = interactor
        self.canEdit = canEdit
        super.init()
    }
    
    func viewDidLoad() {
        interactor.load()
        view.canWrite = canEdit
    }
    
    func didTapInsert() {
        let alertController = UIAlertController(title: "New employee", message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter employee name"
        }
        alertController.addAction(UIAlertAction(title: "Add", style: .default, handler: { [interactor](_) in
            interactor.insertEmployee(name: alertController.textFields?.first?.text ?? "")
        }))
        view?.present(alertController, animated: true, completion: nil)
    }
    
    func didSelectEmployee(at index: Int) {
        guard view.canWrite else {
            showReadOnlyPermission()
            return
        }
        
        let employee = employees[index]
        let alertController = UIAlertController(title: "Update employee", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Add photo", style: .default, handler: { [weak self](_) in
            self?.presentImagePicker(for: employee)
        }))
        alertController.addAction(UIAlertAction(title: "Clear photo", style: .default, handler: { [interactor](_) in
            interactor.update(employee: employee, name: employee.name, photo: nil)
        }))
        alertController.addAction(UIAlertAction(title: "Clear name", style: .default, handler: { [interactor](_) in
            interactor.update(employee: employee, name: nil, photo: employee.photo)
        }))
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter new name"
        }
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { [interactor](_) in
            let name = alertController.textFields?.first?.text
            interactor.update(employee: employee, name: name, photo: employee.photo)
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        view.present(alertController, animated: true, completion: nil)
    }
    
    func showReadOnlyPermission() {
        let alertController = UIAlertController(title: "Read only", message: "You only have read permission for this employee", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        view.present(alertController, animated: true, completion: nil)
    }
    
    func delete(at index: Int) {
        interactor.delete(employee: employees[index])
    }
    
    func presentImagePicker(for employee: Employee) {
        editingEmployee = employee
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        view.present(imagePickerController, animated: true, completion: nil)
    }
}

extension DefaultEmployeePresenter: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let employee = editingEmployee,
            let image = info[.originalImage] as? UIImage,
            let resizedImage = getImage(with: image, size: CGSize(width: 150, height: 150)) {
            interactor.update(employee: employee, name: employee.name, photo: resizedImage.pngData())
        }
        view.dismiss(animated: true, completion: nil)
    }
    
    func getImage(with image: UIImage, size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0);
        image.draw(in: CGRect(origin: .zero, size: size))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}

extension DefaultEmployeePresenter: EmployeeInteractorDelegate {
    func didUpdateEmployees(_ employees: [Employee]) {
        self.employees = employees
    }
}
