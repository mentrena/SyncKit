//
//  QSEmployee.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 31/08/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import RealmSwift

class QSEmployee: Object {

    dynamic var name: String? = ""
    let sortIndex = RealmOptional<Int>()
    dynamic var identifier = ""
    dynamic var photo: Data? = nil
    
    dynamic var company: QSCompany?
    
    override class func primaryKey() -> String? {
        return "identifier"
    }
}
