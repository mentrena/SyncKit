//
//  QSCompany.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 31/08/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import Realm
import SyncKit

class QSCompany: RLMObject, PrimaryKey {
    
    @objc dynamic var name: String? = ""
    @objc dynamic var identifier = ""
    @objc dynamic var sortIndex = 0
    
    var employees: RLMResults<QSEmployee> {
        return QSEmployee.objects(in: realm!, with: NSPredicate(format: "company == %@", self)) as! RLMResults<QSEmployee>
    }
    
    override class func primaryKey() -> String {
        
        return "identifier"
    }
}
