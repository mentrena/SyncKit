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

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSSyncedEntity> {
        return NSFetchRequest<QSSyncedEntity>(entityName: "QSSyncedEntity")
    }

    @NSManaged public var changedKeys: String?
    @NSManaged public var entityType: String?
    @NSManaged public var identifier: String?
    @NSManaged public var originObjectID: String?
    @NSManaged public var state: NSNumber?
    @NSManaged public var updatedDate: NSDate?
    @NSManaged public var pendingRelationships: NSSet?
    @NSManaged public var record: QSRecord?
    @NSManaged public var share: QSSyncedEntity?
    @NSManaged public var shareForEntity: QSSyncedEntity?

}

// MARK: Generated accessors for pendingRelationships
extension QSSyncedEntity {

    @objc(addPendingRelationshipsObject:)
    @NSManaged public func addToPendingRelationships(_ value: QSPendingRelationship)

    @objc(removePendingRelationshipsObject:)
    @NSManaged public func removeFromPendingRelationships(_ value: QSPendingRelationship)

    @objc(addPendingRelationships:)
    @NSManaged public func addToPendingRelationships(_ values: NSSet)

    @objc(removePendingRelationships:)
    @NSManaged public func removeFromPendingRelationships(_ values: NSSet)
    
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
