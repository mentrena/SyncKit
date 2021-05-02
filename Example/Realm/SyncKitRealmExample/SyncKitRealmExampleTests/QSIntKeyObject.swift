//
//  QSIntKeyObject.swift
//  SyncKitRealmExampleTests
//
//  Created by Manuel Entrena on 02/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//

import Realm
import SyncKit

class QSIntKeyObject: RLMObject, PrimaryKey {
    
    @objc dynamic var name: String? = ""
    @objc dynamic var identifier = 0
    
    override class func primaryKey() -> String {
        
        return "identifier"
    }
}
