//
//  CoreDataAdapter+Notifications.swift
//  SyncKit
//
//  Created by Manuel Entrena on 06/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CoreData

extension CoreDataAdapter {
    @objc func targetContextWillSave(notification: Notification) {
        if let object = notification.object as? NSManagedObjectContext,
            object == targetContext && !isMergingImportedChanges {
            let updated = Array(targetContext.updatedObjects)
            var identifiersAndChanges = [String: [String]]()
            for object in updated {
                var changedValueKeys = [String]()
                for key in object.changedValues().keys {
                    let relationship = object.entity.relationshipsByName[key]
                    
                    if object.entity.attributesByName[key] != nil ||
                        (relationship != nil && relationship!.isToMany == false) {
                        changedValueKeys.append(key)
                    }
                }
                if let identifier = uniqueIdentifier(for: object),
                    changedValueKeys.count > 0 {
                    identifiersAndChanges[identifier] = changedValueKeys
                }
            }
            
            let deletedIDs: [String] = targetContext.deletedObjects.compactMap {
                if self.uniqueIdentifier(for: $0) == nil,
                    let entityName = $0.entity.name {
                    // Properties become nil when objects are deleted as a result of using an undo manager
                    // Here we can retrieve their last known identifier and mark the corresponding synced
                    // entity for deletion
                    let identifierFieldName = self.identifierFieldName(forEntity: entityName)
                    let committedValues = $0.committedValues(forKeys: [identifierFieldName])
                    return committedValues[identifierFieldName] as? String
                } else {
                    return uniqueIdentifier(for: $0)
                }
            }
            
            privateContext.perform {
                for (identifier, objectChangedKeys) in identifiersAndChanges {
                    guard let entity = self.syncedEntity(withOriginIdentifier: identifier) else { continue }
                    
                    var changedKeys = Set<String>(entity.changedKeysArray)
                    for key in objectChangedKeys {
                        changedKeys.insert(key)
                    }
                    entity.changedKeysArray = Array(changedKeys)
                    entity.entityState = .changed
                    entity.updatedDate = NSDate()
                }
                
                deletedIDs.forEach { (identifier) in
                    guard let entity = self.syncedEntity(withOriginIdentifier: identifier) else { return }
                    entity.entityState = .deleted
                    entity.updatedDate = NSDate()
                }
                
                debugPrint("QSCloudKitSynchronizer >> Will Save >> Tracking %ld updates", updated.count)
                debugPrint("QSCloudKitSynchronizer >> Will Save >> Tracking %ld deletions", deletedIDs.count)
                
                self.savePrivateContext()
            }
        }
    }
    
    @objc func targetContextDidSave(notification: Notification) {
        if let object = notification.object as? NSManagedObjectContext,
            object == targetContext && !isMergingImportedChanges {
            let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>
            let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>
            let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>
            
            var insertedIdentifiersAndEntityNames = [String: String]()
            inserted?.forEach {
                if let entityName = $0.entity.name,
                    let identifier = uniqueIdentifier(for: $0) {
                    insertedIdentifiersAndEntityNames[identifier] = entityName
                }
            }
            
            let updatedCount = updated?.count ?? 0
            let deletedCount = deleted?.count ?? 0
            
            let willHaveChanges = !insertedIdentifiersAndEntityNames.isEmpty || updatedCount > 0 || deletedCount > 0
            
            privateContext.perform {
                insertedIdentifiersAndEntityNames.forEach({ (identifier, entityName) in
                    let entity = self.syncedEntity(withOriginIdentifier: identifier)
                    if entity == nil {
                        self.createSyncedEntity(identifier: identifier, entityName: entityName)
                    }
                })
                
                debugPrint("QSCloudKitSynchronizer >> Did Save >> Tracking %ld insertions", inserted?.count ?? 0)
                
                self.savePrivateContext()
                
                if willHaveChanges {
                    self.hasChanges = true
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .ModelAdapterHasChangesNotification, object: self)
                    }
                }
            }
        }
    }
}
