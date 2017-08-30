//
//  PendingRelationship.swift
//  Pods
//
//  Created by Manuel Entrena on 29/08/2017.
//
//

import RealmSwift

class PendingRelationship: Object {
    
    dynamic var relationshipName: String!
    dynamic var targetIdentifier: String!
    dynamic var forSyncedEntity: SyncedEntity!
}
