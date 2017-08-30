//
//  SyncedEntity.swift
//  Pods
//
//  Created by Manuel Entrena on 29/08/2017.
//
//

import RealmSwift

class SyncedEntity: Object {
    
    dynamic var entityType: String = ""
    dynamic var identifier: String = ""
    dynamic var state: Int = 0
    dynamic var changedKeys: String?
    dynamic var updated: Date?
    dynamic var record: Record?
    
    convenience init(entityType: String, identifier: String, state: Int) {
        
        self.init()
        
        self.entityType = entityType
        self.identifier = identifier
        self.state = state
    }
    
    override static func primaryKey() -> String? {
        
        return "identifier"
    }
}
