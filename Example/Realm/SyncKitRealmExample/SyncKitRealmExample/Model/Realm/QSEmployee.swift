//
//  QSEmployee.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 31/08/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import Realm
import SyncKit

class QSEmployee: RLMObject, PrimaryKey, ParentKey {

    @objc dynamic var name: String? = ""
    @objc dynamic var identifier = ""
    @objc dynamic var photo: Data? = nil
    @objc dynamic var sortIndex = 0
    
    @objc dynamic var company: QSCompany?
    
    override class func primaryKey() -> String {
        return "identifier"
    }
    
    static func parentKey() -> String {
        return "company"
    }
}
