//
//  QSIntKeyObject.swift
//  SyncKitRealmExampleTests
//
//  Created by Manuel Entrena on 02/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//

import Realm
import SyncKit

class QSCompany_Int: RLMObject, PrimaryKey {
    
    @objc dynamic var name: String? = ""
    @objc dynamic var identifier = 0
    @objc dynamic var sortIndex = 0
    
    var employees: RLMResults<QSEmployee_Int> {
        return QSEmployee_Int.objects(in: realm!, with: NSPredicate(format: "company == %@", self)) as! RLMResults<QSEmployee_Int>
    }
    
    override class func primaryKey() -> String {
        
        return "identifier"
    }
}

class QSEmployee_Int: RLMObject, PrimaryKey, ParentKey {

    @objc dynamic var name: String? = ""
    @objc dynamic var identifier = 0
    @objc dynamic var photo: Data? = nil
    @objc dynamic var sortIndex = 0
    
    @objc dynamic var company: QSCompany_Int?
    
    override class func primaryKey() -> String {
        return "identifier"
    }
    
    static func parentKey() -> String {
        return "company"
    }
}
