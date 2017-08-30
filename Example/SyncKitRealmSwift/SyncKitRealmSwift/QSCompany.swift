//
//  QSCompany.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 31/08/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import RealmSwift

class QSCompany: Object {
    
    dynamic var name: String? = ""
    dynamic var identifier = ""
    let sortIndex = RealmOptional<Int>()
    
    let employees = LinkingObjects(fromType: QSEmployee.self, property: "company")
    
    override class func primaryKey() -> String? {
        
        return "identifier"
    }
}
