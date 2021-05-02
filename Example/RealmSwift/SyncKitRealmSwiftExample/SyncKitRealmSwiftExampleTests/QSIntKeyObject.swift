//
//  QSIntKeyObject.swift
//  SyncKitRealmSwiftExampleTests
//
//  Created by Manuel Entrena on 02/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//

import RealmSwift
import SyncKit

class QSIntKeyObject: Object, PrimaryKey {
    
    @objc dynamic var name: String? = ""
    @objc dynamic var identifier: Int = 0
    
    override class func primaryKey() -> String {
        
        return "identifier"
    }
}
