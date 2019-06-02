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
                let identifier = uniqueIdentifier(for: object)
                var changedValueKeys = [String]()
                for key in object.changedValues().keys {
                    let relationship = object.entity.relationshipsByName[key]
                    
                    if object.entity.attributesByName[key] != nil ||
                        (relationship != nil && relationship!.isToMany == false) {
                        changedValueKeys.append(key)
                    }
                }
                if changedValueKeys.count > 0 {
                    identifiersAndChanges[identifier] = changedValueKeys
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
                }
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
                if let entityName = $0.entity.name {
                    insertedIdentifiersAndEntityNames[uniqueIdentifier(for: $0)] = entityName
                }
            }
            
            let updatedIDs = updated?.map { uniqueIdentifier(for: $0) } ?? []
            let deletedIDs = deleted?.map { uniqueIdentifier(for: $0) } ?? []
            
            let willHaveChanges = !insertedIdentifiersAndEntityNames.isEmpty || !updatedIDs.isEmpty || !deletedIDs.isEmpty
            
            privateContext.perform {
                insertedIdentifiersAndEntityNames.forEach({ (identifier, entityName) in
                    let entity = self.syncedEntity(withOriginIdentifier: identifier)
                    if entity == nil {
                        self.createSyncedEntity(identifier: identifier, entityName: entityName)
                    }
                })
                
                updatedIDs.forEach({ (identifier) in
                    guard let entity = self.syncedEntity(withOriginIdentifier: identifier) else { return }
                    if entity.entityState == .synced && !entity.changedKeysArray.isEmpty {
                        entity.entityState = .changed
                    }
                    entity.updatedDate = NSDate()
                })
                
                deletedIDs.forEach { (identifier) in
                    guard let entity = self.syncedEntity(withOriginIdentifier: identifier) else { return }
                    entity.entityState = .deleted
                    entity.updatedDate = NSDate()
                }
                
                debugPrint("QSCloudKitSynchronizer >> Tracking %ld insertions", inserted?.count ?? 0)
                debugPrint("QSCloudKitSynchronizer >> Tracking %ld updates", updated?.count ?? 0)
                debugPrint("QSCloudKitSynchronizer >> Tracking %ld deletions", deleted?.count ?? 0)
                
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
