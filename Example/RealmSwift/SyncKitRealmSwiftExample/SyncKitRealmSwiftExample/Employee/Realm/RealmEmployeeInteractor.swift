//
//  RealmEmployeeInteractor.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 26/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import RealmSwift

class RealmEmployeeInteractor: EmployeeInteractor {
    
    let realm: Realm
    let company: Company
    let modelCompany: QSCompany!

    var employees: Results<QSEmployee>!
    var notificationToken: NotificationToken!
    
    weak var delegate: EmployeeInteractorDelegate?
    
    init(realm: Realm, company: Company) {
        self.realm = realm
        self.company = company
        modelCompany = realm.object(ofType: QSCompany.self, forPrimaryKey: company.identifier)
    }
    
    func load() {
        employees = realm.objects(QSEmployee.self).filter("company == %@", modelCompany!).sorted(byKeyPath: "name")
        self.update(employees: Array(self.employees))
        notificationToken = employees.observe({ [weak self](changes) in
            guard let self = self else { return }
            self.update(employees: Array(self.employees))
        })
    }
    
    func insertEmployee(name: String) {
        let employee = QSEmployee()
        employee.name = name
        employee.company = modelCompany
        employee.identifier = NSUUID().uuidString
        
        realm.beginWrite()
        realm.add(employee)
        try! realm.commitWrite()
    }
    
    func delete(employee: Employee) {
        guard let emp = employees.first(where: {
            $0.identifier == employee.identifier
        }) else { return }
        try! realm.write {
            realm.delete(emp)
        }
    }
    
    func update(employee: Employee, name: String?, photo: Data?) {
        guard let emp = employees.first(where: {
            $0.identifier == employee.identifier
        }) else { return }
        
        try! realm.write {
            emp.name = name
            emp.photo = photo
        }
    }
    
    func update(employees: [QSEmployee]?) {
        let translatedEmployees = employees?.map {
            Employee(name: $0.name,
                     identifier: $0.identifier,
                     photo: $0.photo as Data?)
            } ?? []
        delegate?.didUpdateEmployees(translatedEmployees)
    }
}
