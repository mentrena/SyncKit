//
//  QSObjectIdKeyObject.swift
//  SyncKitRealmExampleTests
//
//  Created by Manuel Entrena on 02/05/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//

import Realm
import SyncKit

class QSObjectIdKeyObject: RLMObject, PrimaryKey {
    
    @objc dynamic var name: String? = ""
    @objc dynamic var identifier = RLMObjectId()
    
    override class func primaryKey() -> String {
        
        return "identifier"
    }
}
