//
//  RealmEmployeeInteractor.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 26/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import RealmSwift

class RealmEmployeeInteractor_Int: EmployeeInteractor {
    
    let realm: Realm
    let company: Company
    let modelCompany: QSCompany_Int!

    var employees: Results<QSEmployee_Int>!
    var notificationToken: NotificationToken!
    
    weak var delegate: EmployeeInteractorDelegate?
    
    init(realm: Realm, company: Company) {
        self.realm = realm
        self.company = company
        let id: Int
        switch company.identifier {
        case .string(let value): id = Int(value)!
        case .int(let value): id = value
        }
        modelCompany = realm.object(ofType: QSCompany_Int.self, forPrimaryKey: id)
    }
    
    func load() {
        employees = realm.objects(QSEmployee_Int.self).filter("company == %@", modelCompany!).sorted(byKeyPath: "name")
        self.update(employees: Array(self.employees))
        notificationToken = employees.observe({ [weak self](changes) in
            guard let self = self else { return }
            self.update(employees: Array(self.employees))
        })
    }
    
    func insertEmployee(name: String) {
        let employee = QSEmployee_Int()
        employee.name = name
        employee.company = modelCompany
        employee.identifier = Identifier.generateInt()
        
        realm.beginWrite()
        realm.add(employee)
        try! realm.commitWrite()
    }
    
    func delete(employee: Employee) {
        guard case .int(let id) = employee.identifier else { return }
        guard let emp = employees.first(where: {
            $0.identifier == id
        }) else { return }
        try! realm.write {
            realm.delete(emp)
        }
    }
    
    func update(employee: Employee, name: String?, photo: Data?) {
        guard case .int(let id) = employee.identifier else { return }
        guard let emp = employees.first(where: {
            $0.identifier == id
        }) else { return }
        
        try! realm.write {
            emp.name = name
            emp.photo = photo
        }
    }
    
    func update(employees: [QSEmployee_Int]?) {
        let translatedEmployees = employees?.map {
            Employee(name: $0.name,
                     identifier: .int(value: $0.identifier),
                     photo: $0.photo as Data?)
            } ?? []
        delegate?.didUpdateEmployees(translatedEmployees)
    }
}
