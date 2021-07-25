//
//  CoreDataEmployeeInteractor.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CoreData

class CoreDataEmployeeInteractor: NSObject, EmployeeInteractor {
    
    let managedObjectContext: NSManagedObjectContext
    let fetchedResultsController: NSFetchedResultsController<QSEmployee>
    let company: Company
    weak var delegate: EmployeeInteractorDelegate?
    
    init(managedObjectContext: NSManagedObjectContext, company: Company) {
        self.managedObjectContext = managedObjectContext
        self.company = company
        let fetchRequest = NSFetchRequest<QSEmployee>(entityName: "QSEmployee")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let predicate = NSPredicate(format: "company.identifier == %@", company.identifier.stringValue!)
        fetchRequest.predicate = predicate
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                              managedObjectContext: managedObjectContext,
                                                              sectionNameKeyPath: nil,
                                                              cacheName: nil)
        super.init()
        fetchedResultsController.delegate = self
    }
    
    func load() {
        try? fetchedResultsController.performFetch()
        update(employees: fetchedResultsController.fetchedObjects)
    }
    
    func insertEmployee(name: String) {
        guard let parent = try? managedObjectContext.executeFetchRequest(entityName: "QSCompany", predicate: NSPredicate(format: "identifier == %@", company.identifier.stringValue!)).first as? QSCompany else {
            return
        }
        let employee = NSEntityDescription.insertNewObject(forEntityName: "QSEmployee", into: managedObjectContext) as! QSEmployee
        employee.identifier = UUID().uuidString
        employee.name = name
        employee.company = parent
        try? managedObjectContext.save()
    }
    
    func update(employees: [QSEmployee]?) {
        let translatedEmployees = employees?.map {
            Employee(name: $0.name, identifier: Identifier.string(value: $0.identifier!), photo: $0.photo as Data?)
            } ?? []
        delegate?.didUpdateEmployees(translatedEmployees)
    }
    
    func fetchEmployee(with employee: Employee) -> QSEmployee? {
        return fetchedResultsController.fetchedObjects?.first(where: { (emp) -> Bool in
            emp.identifier == employee.identifier.stringValue
        })
    }
    
    func delete(employee: Employee) {
        guard let employee = fetchEmployee(with: employee) else { return }
        
        managedObjectContext.delete(employee)
        try? managedObjectContext.save()
    }
    
    func update(employee: Employee, name: String?, photo: Data?) {
        guard let employee = fetchEmployee(with: employee) else { return }
        employee.name = name
        employee.photo = photo
        try? managedObjectContext.save()
    }
}

extension CoreDataEmployeeInteractor: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        update(employees: fetchedResultsController.fetchedObjects)
    }
}
