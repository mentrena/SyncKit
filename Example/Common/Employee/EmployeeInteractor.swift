//
//  EmployeeInteractor.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation

protocol EmployeeInteractor: class {
    func load()
    func insertEmployee(name: String)
    func delete(employee: Employee)
    func update(employee: Employee, name: String?, photo: Data?)
}

protocol EmployeeInteractorDelegate: class {
    func didUpdateEmployees(_ employees: [Employee])
}
