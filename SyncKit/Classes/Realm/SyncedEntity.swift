//
//  SyncedEntity.swift
//  Pods
//
//  Created by Manuel Entrena on 29/08/2017.
//
//

import Foundation
import Realm

class SyncedEntity: RLMObject {
    
    @objc dynamic var entityType: String = ""
    @objc dynamic var identifier: String = ""
    @objc dynamic var state: Int = 0
    @objc dynamic var changedKeys: String?
    @objc dynamic var updated: Date?
    @objc dynamic var record: Record?
    @objc dynamic var share: SyncedEntity?
    
    convenience init(entityType: String, identifier: String, state: Int) {
        
        self.init()
        
        self.entityType = entityType
        self.identifier = identifier
        self.state = state
    }
    
    override static func primaryKey() -> String? {
        
        return "identifier"
    }
    
    var entityState: SyncedEntityState {
        set {
            state = newValue.rawValue
        }
        get {
            return SyncedEntityState(rawValue: state)!
        }
    }
}
