//
//  QSObjectIdKeyObject.swift
//  SyncKitRealmExampleTests
//
//  Created by Manuel Entrena on 02/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//

import Realm
import SyncKit

class QSCompany_ObjId: RLMObject, PrimaryKey {
    
    @objc dynamic var name: String? = ""
    @objc dynamic var identifier = RLMObjectId()
    @objc dynamic var sortIndex = 0
    
    var employees: RLMResults<QSEmployee_ObjId> {
        return QSEmployee_ObjId.objects(in: realm!, with: NSPredicate(format: "company == %@", self)) as! RLMResults<QSEmployee_ObjId>
    }
    
    override class func primaryKey() -> String {
        
        return "identifier"
    }
}

class QSEmployee_ObjId: RLMObject, PrimaryKey, ParentKey {

    @objc dynamic var name: String? = ""
    @objc dynamic var identifier = RLMObjectId()
    @objc dynamic var photo: Data? = nil
    @objc dynamic var sortIndex = 0
    
    @objc dynamic var company: QSCompany_ObjId?
    
    override class func primaryKey() -> String {
        return "identifier"
    }
    
    static func parentKey() -> String {
        return "company"
    }
}
