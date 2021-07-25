//
//  RealmEmployeeInteractor.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 26/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import Realm

class RealmEmployeeInteractor: EmployeeInteractor {
    
    let realm: RLMRealm
    let company: Company
    let modelCompany: QSCompany!

    var employees: RLMResults<QSEmployee>!
    var notificationToken: RLMNotificationToken!
    
    weak var delegate: EmployeeInteractorDelegate?
    
    init(realm: RLMRealm, company: Company) {
        self.realm = realm
        self.company = company
        modelCompany = QSCompany.object(in: realm, forPrimaryKey: company.identifier.stringValue)
    }
    
    func load() {
        employees = (QSEmployee.objects(in: realm, with: NSPredicate(format: "company == %@", modelCompany)).sortedResults(usingKeyPath: "name", ascending: true) as! RLMResults<QSEmployee>)
        self.update(employees: employees)
        notificationToken = employees.addNotificationBlock({ [weak self] (_, _, _) in
            guard let self = self else { return }
            self.update(employees: self.employees)
        })
    }
    
    func insertEmployee(name: String) {
        let employee = QSEmployee()
        employee.name = name
        employee.company = modelCompany
        employee.identifier = NSUUID().uuidString
        
        realm.beginWriteTransaction()
        realm.add(employee)
        try! realm.commitWriteTransaction()
    }
    
    func delete(employee: Employee) {
        guard let emp = employees.first(where: {
            ($0 as? QSEmployee)?.identifier == employee.identifier.stringValue
        }) as? QSEmployee else { return }
        
        realm.beginWriteTransaction()
        realm.delete(emp)
        try! realm.commitWriteTransaction()
    }
    
    func update(employee: Employee, name: String?, photo: Data?) {
        guard let emp = employees.first(where: {
            ($0 as? QSEmployee)?.identifier == employee.identifier.stringValue
        }) as? QSEmployee else { return }
        
        realm.beginWriteTransaction()
        emp.name = name
        emp.photo = photo
        try! realm.commitWriteTransaction()
    }
    
    func update(employees: RLMResults<QSEmployee>?) {
        let translatedEmployees = employees?.map { object -> Employee in
            let emp = object as! QSEmployee
            return Employee(name: emp.name,
                            identifier: Identifier.string(value: emp.identifier),
                            photo: emp.photo as Data?)
            } ?? []
        delegate?.didUpdateEmployees(translatedEmployees)
    }
}
