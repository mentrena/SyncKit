//
//  PendingRelationship.swift
//  Pods
//
//  Created by Manuel Entrena on 29/08/2017.
//
//

import Foundation
import Realm

class PendingRelationship: RLMObject {
    
    @objc dynamic var relationshipName: String!
    @objc dynamic var targetIdentifier: String!
    @objc dynamic var forSyncedEntity: SyncedEntity!
}
