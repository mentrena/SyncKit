//
//  QSSyncedEntity+CoreDataProperties.swift
//  
//
//  Created by Manuel Entrena on 02/06/2019.
//
//

import Foundation
import CoreData


extension QSSyncedEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<QSSyncedEntity> {
        return NSFetchRequest<QSSyncedEntity>(entityName: "QSSyncedEntity")
    }

    @NSManaged var changedKeys: String?
    @NSManaged var entityType: String?
    @NSManaged var identifier: String?
    @NSManaged var originObjectID: String?
    @NSManaged var state: NSNumber?
    @NSManaged var updatedDate: NSDate?
    @NSManaged var pendingRelationships: NSSet?
    @NSManaged var record: QSRecord?
    @NSManaged var share: QSSyncedEntity?
    @NSManaged var shareForEntity: QSSyncedEntity?

}

// MARK: Generated accessors for pendingRelationships
extension QSSyncedEntity {

    @objc(addPendingRelationshipsObject:)
    @NSManaged func addToPendingRelationships(_ value: QSPendingRelationship)

    @objc(removePendingRelationshipsObject:)
    @NSManaged func removeFromPendingRelationships(_ value: QSPendingRelationship)

    @objc(addPendingRelationships:)
    @NSManaged func addToPendingRelationships(_ values: NSSet)

    @objc(removePendingRelationships:)
    @NSManaged func removeFromPendingRelationships(_ values: NSSet)
    
    var entityState: SyncedEntityState {
        set {
            state = newValue.rawValue as NSNumber
        }
        get {
            return SyncedEntityState(rawValue: state?.intValue ?? 0)!
        }
    }
    
    var isShare: Bool {
        return entityType == "CKShare"
    }

    var changedKeysArray: [String] {
        get {
            guard let keys = changedKeys,
                !keys.isEmpty else { return [] }
            return keys.components(separatedBy: ",")
        }
        set {
            if newValue.count > 0 {
                changedKeys = newValue.joined(separator: ",")
            } else {
                changedKeys = nil
            }
        }
    }
}
