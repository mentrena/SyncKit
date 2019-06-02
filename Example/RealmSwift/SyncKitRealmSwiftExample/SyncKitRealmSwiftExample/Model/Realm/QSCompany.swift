//
//  QSCompany.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 31/08/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import RealmSwift
import SyncKit

class QSCompany: Object, PrimaryKey {
    
    @objc dynamic var name: String? = ""
    @objc dynamic var identifier = ""
    let sortIndex = RealmOptional<Int>()
    
    let employees = LinkingObjects(fromType: QSEmployee.self, property: "company")
    
    override class func primaryKey() -> String {
        
        return "identifier"
    }
}
