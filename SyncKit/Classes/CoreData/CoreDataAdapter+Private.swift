//
//  CoreDataAdapter+Private.swift
//  SyncKit
//
//  Created by Manuel Entrena on 04/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

typealias IdentifiableManagedObject = NSManagedObject & PrimaryKey

//MARK: - Utilities
extension CoreDataAdapter {
    func savePrivateContext() {
        try? self.privateContext.save()
    }
    
    func configureImportContext() {
        targetImportContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        targetImportContext.parent = targetContext
    }
    
    func clearImportContext() {
        guard let targetImportContext = targetImportContext else { return }
        targetImportContext.performAndWait {
            self.targetImportContext.reset()
        }
        self.targetImportContext = nil
    }
    
    func deleteAllPendingRelationships() {
        guard let pendingRelationships = try? privateContext.executeFetchRequest(entityName: "QSPendingRelationship") as? [QSPendingRelationship] else { return }
        pendingRelationships.forEach {
            self.privateContext.delete($0)
        }
    }
    
    func deleteInsertedButUnmergedEntities() {
        let pendingEntities = fetchEntities(state: .inserted)
        pendingEntities.forEach {
            self.privateContext.delete($0)
        }
    }
    
    func updateInsertedEntitiesAndSave() {
        for pending in self.fetchEntities(state: .inserted) {
            pending.entityState = .synced
        }
        savePrivateContext()
    }
    
    func nextStateToSync(after state: SyncedEntityState) -> SyncedEntityState {
        return SyncedEntityState(rawValue: state.rawValue + 1)!
    }
    
    func shouldIgnore(key: String) -> Bool {
        return key == CoreDataAdapter.timestampKey || CloudKitSynchronizer.metadataKeys.contains(key)
    }
    
    func transformedValue(_ value: Any, valueTransformerName: String?) -> Any? {
        if let valueTransformerName = valueTransformerName {
            let transformer = ValueTransformer(forName: NSValueTransformerName(valueTransformerName))
            return transformer?.transformedValue(value)
        } else if let data = value as? Data {
            return QSCoder.shared.object(from: data)
        } else {
            return nil
        }
    }
    
    func reverseTransformedValue(_ value: Any, valueTransformerName: String?) -> Any? {
        if let valueTransformerName = valueTransformerName {
            let transformer = ValueTransformer(forName: NSValueTransformerName(valueTransformerName))
            return transformer?.reverseTransformedValue(value)
        } else {
            return QSCoder.shared.data(from: value)
        }
    }
    
    func threadSafePrimaryKeyValue(for object: NSManagedObject) -> PrimaryKeyValue {
        var identifier: PrimaryKeyValue! = nil
        object.managedObjectContext!.performAndWait {
            identifier = self.uniqueIdentifier(for: object)
        }
        return identifier
    }
}

//MARK: - Object Identifiers
extension CoreDataAdapter {
    func identifierFieldName(forEntity entityName: String) -> String {
        return entityPrimaryKeys[entityName]!.name;
    }
    
    func uniqueIdentifier(for object: NSManagedObject) -> PrimaryKeyValue? {
        guard let entityName = object.entity.name,
              let value = object.value(forKey: identifierFieldName(forEntity: entityName)) else {
            return nil
        }
            
        return PrimaryKeyValue(value: value)
    }
    
    func getObjectIdentifier(for syncedEntity: QSSyncedEntity) -> PrimaryKeyValue? {
        guard let identifier = syncedEntity.originObjectID,
              let entityType = syncedEntity.entityType,
              let attributeType = entityPrimaryKeys[entityType]?.type else {
            return nil
        }
        return PrimaryKeyValue(stringValue: identifier, attributeType: attributeType)
    }
    
    func getObjectIdentifier(stringObjectId: String, entityType: String) -> PrimaryKeyValue? {
        guard let attributeType = entityPrimaryKeys[entityType]?.type else {
            return nil
        }
        return PrimaryKeyValue(stringValue: stringObjectId, attributeType: attributeType)
    }
    
    func uniqueIdentifier(forObjectFrom record: CKRecord) -> PrimaryKeyValue? {
        let entityType = record.recordType
        let name = record.recordID.recordName
        let index = name.index(name.startIndex, offsetBy: entityType.count + 1)
        let stringId = String(name[index...])
        guard let attributeType = entityPrimaryKeys[entityType]?.type else { return nil }
        return PrimaryKeyValue(stringValue: stringId, attributeType: attributeType)
    }
}

//MARK: - Entities
extension CoreDataAdapter {
    func createSyncedEntity(identifier: String, entityName: String) {
        
        guard let entityDescription = NSEntityDescription.entity(forEntityName: "QSSyncedEntity", in: privateContext) else { return }
        let syncedEntity = QSSyncedEntity(entity: entityDescription, insertInto: privateContext)
        
        syncedEntity.entityType = entityName
        syncedEntity.entityState = .new
        syncedEntity.updatedDate = NSDate()
        syncedEntity.originObjectID = identifier
        syncedEntity.identifier = "\(entityName).\(identifier)"
    }
    
    func createSyncedEntity(share: CKShare) -> QSSyncedEntity? {
        let entityForShare = QSSyncedEntity(entity: NSEntityDescription.entity(forEntityName: "QSSyncedEntity", in: privateContext)!,
                                            insertInto: privateContext)
        entityForShare.entityType = "CKShare"
        entityForShare.identifier = share.recordID.recordName
        entityForShare.updatedDate = NSDate()
        entityForShare.entityState = .synced
        return entityForShare
    }
    
    func createSyncedEntity(record: CKRecord) -> QSSyncedEntity? {
        let syncedEntity = QSSyncedEntity(entity: NSEntityDescription.entity(forEntityName: "QSSyncedEntity", in: privateContext)!,
                                          insertInto: privateContext)
        syncedEntity.identifier = record.recordID.recordName
        let entityName = record.recordType
        syncedEntity.entityType = entityName
        syncedEntity.updatedDate = NSDate()
        syncedEntity.entityState = .inserted
        
        var objectID: PrimaryKeyValue!
        targetImportContext.performAndWait {
            let object = self.insertManagedObject(entityName: entityName)
            objectID = self.uniqueIdentifier(forObjectFrom: record)
            object.setValue(objectID.value, forKey: self.identifierFieldName(forEntity: entityName))
        }
        
        syncedEntity.originObjectID = objectID.description
        return syncedEntity
    }
    
    func syncedEntity(withOriginIdentifier identifier: PrimaryKeyValue) -> QSSyncedEntity? {
        let fetched = try? self.privateContext.executeFetchRequest(entityName: "QSSyncedEntity",
                                                                   predicate: NSPredicate(format: "originObjectID == %@", identifier.description),
                                                                   fetchLimit: 1) as? [QSSyncedEntity]
        return fetched?.first
    }
    
    func syncedEntity(withIdentifier identifier: String) -> QSSyncedEntity? {
        let fetched = try? self.privateContext.executeFetchRequest(entityName: "QSSyncedEntity",
                                                                   predicate: NSPredicate(format: "identifier == %@", identifier),
                                                                   fetchLimit: 1) as? [QSSyncedEntity]
        return fetched?.first
    }
    
    @available(iOS 15.0, OSX 12, watchOS 8.0, *)
    func syncedEntityForRecordZoneShare() -> QSSyncedEntity? {
        let fetched = try? self.privateContext.executeFetchRequest(entityName: "QSSyncedEntity",
                                                                   predicate: NSPredicate(format: "identifier == %@", CKRecordNameZoneWideShare),
                                                                   fetchLimit: 1) as? [QSSyncedEntity]
        return fetched?.first
    }
    
    func fetchEntities(state: SyncedEntityState) -> [QSSyncedEntity] {
        return try! privateContext.executeFetchRequest(entityName: "QSSyncedEntity", predicate: NSPredicate(format: "state == %lud", state.rawValue)) as! [QSSyncedEntity]
    }
    
    func fetchEntities(identifiers: [String]) -> [QSSyncedEntity] {
        return try! privateContext.executeFetchRequest(entityName: "QSSyncedEntity",
                                                       predicate: NSPredicate(format: "identifier IN %@", identifiers),
                                                       preload: true) as! [QSSyncedEntity]
    }
    
    func delete(syncedEntities: [QSSyncedEntity]) {
        var identifiersByType = [String: [PrimaryKeyValue]]()
        for syncedEntity in syncedEntities {
            
            if let originObjectID = getObjectIdentifier(for: syncedEntity),
                let entityType = syncedEntity.entityType,
                entityType != "CKShare" && syncedEntity.entityState != .deleted {
                if identifiersByType[entityType] == nil {
                    identifiersByType[entityType] = [PrimaryKeyValue]()
                }
                identifiersByType[entityType]?.append(originObjectID)
            }
            
            privateContext.delete(syncedEntity)
        }
        
        targetImportContext.performAndWait {
            identifiersByType.forEach({ (entityType, identifiers) in
                let objects = self.managedObjects(entityName: entityType,
                                                  identifiers: identifiers,
                                                  context: self.targetImportContext)
                objects.forEach {
                    self.targetImportContext.delete($0)
                }
            })
        }
    }
    
    func save(record: CKRecord, for entity: QSSyncedEntity) {
        var qsRecord: QSRecord! = entity.record
        if qsRecord == nil {
            qsRecord = QSRecord(entity: NSEntityDescription.entity(forEntityName: "QSRecord", in: privateContext)!,
                                insertInto: privateContext)
            entity.record = qsRecord
        }
        qsRecord.encodedRecord = QSCoder.shared.encode(record) as NSData
    }
    
    func storedRecord(for entity: QSSyncedEntity) -> CKRecord? {
        
        guard let qsRecord = entity.record,
            let data = qsRecord.encodedRecord else {
                return nil
        }
        
        return QSCoder.shared.decode(from: data as Data)
    }
    
    func storedShare(for entity: QSSyncedEntity) -> CKShare? {
        guard let share = entity.share else {
            return nil
        }
        return storedShare(inShareEntity: share)
    }
    
    func storedShare(inShareEntity entity: QSSyncedEntity) -> CKShare? {
        var share: CKShare?
        if let shareData = entity.record?.encodedRecord {
            share = QSCoder.shared.decode(from: shareData as Data)
        }
        return share
    }
    
    func save(share: CKShare, for entity: QSSyncedEntity) {
        var qsRecord: QSRecord!
        if entity.share == nil {
            entity.share = createSyncedEntity(share: share)
            qsRecord = QSRecord(entity: NSEntityDescription.entity(forEntityName: "QSRecord", in: self.privateContext)!,
                                    insertInto: self.privateContext)
            entity.share?.record = qsRecord
        } else {
            qsRecord = entity.share?.record
        }
        qsRecord.encodedRecord = QSCoder.shared.encode(share) as NSData
    }
    
    @available(iOS 15.0, OSX 12, watchOS 8.0, *)
    func saveShareForRecordZoneEntity(share: CKShare) {
        var entity = syncedEntityForRecordZoneShare()
        var qsRecord: QSRecord!
        if entity == nil {
            entity = createSyncedEntity(share: share)
            qsRecord = QSRecord(entity: NSEntityDescription.entity(forEntityName: "QSRecord", in: privateContext)!,
                                insertInto: privateContext)
            entity?.record = qsRecord
        } else {
            qsRecord = entity?.record
        }

        qsRecord.encodedRecord = QSCoder.shared.encode(share) as NSData
    }
    
    func recordsToUpload(state: SyncedEntityState, limit: Int) -> [CKRecord] {
        var recordsArray = [CKRecord]()
        privateContext.performAndWait {
            let entities = fetchEntities(state: state)
            var pending = entities
            var includedEntityIDs = Set<String>()
            while recordsArray.count < limit && !pending.isEmpty {
                var entity: QSSyncedEntity! = pending.removeLast()
                while entity != nil && entity.entityState == state && !includedEntityIDs.contains(entity.identifier!) {
                    var parentEntity: QSSyncedEntity? = nil
                    if let index = pending.firstIndex(of: entity) {
                        pending.remove(at: index)
                    }
                    let record = self.recordToUpload(for: entity, context: self.targetContext, parentEntity: &parentEntity)
                    recordsArray.append(record)
                    includedEntityIDs.insert(entity.identifier!)
                    entity = parentEntity
                }
            }
        }
        return recordsArray
    }
    
    func recordToUpload(for entity: QSSyncedEntity, context: NSManagedObjectContext, parentEntity: inout QSSyncedEntity?) -> CKRecord {
        var record: CKRecord! = storedRecord(for: entity)
        if record == nil {
            record = CKRecord(recordType: entity.entityType!,
                              recordID: CKRecord.ID(recordName: entity.identifier!, zoneID: recordZoneID))
        }
        
        var originalObject: NSManagedObject!
        var entityDescription: NSEntityDescription!
        let objectID = self.getObjectIdentifier(for: entity)!
        let entityState = entity.entityState
        let entityType = entity.entityType!
        let changedKeys = entity.changedKeysArray
        
        context.performAndWait {
            originalObject = self.managedObject(entityName: entityType, identifier: objectID, context: context)
            entityDescription = NSEntityDescription.entity(forEntityName: entityType, in: context)
            let primaryKey = self.identifierFieldName(forEntity: entityType)
            let encryptedFields = self.entityEncryptedFields[entityType]
            // Add attributes
            entityDescription.attributesByName.forEach({ (attributeName, attributeDescription) in
                if attributeName != primaryKey &&
                    (entityState == .new || changedKeys.contains(attributeName)) {
                    
                    if let recordProcessingDelegate = recordProcessingDelegate,
                       !recordProcessingDelegate.shouldProcessPropertyBeforeUpload(propertyName: attributeName, object: originalObject, record: record) {
                        return
                    }
                    
                    let value = originalObject.value(forKey: attributeName)
                    if attributeDescription.attributeType == .binaryDataAttributeType && !self.forceDataTypeInsteadOfAsset,
                        let data = value as? Data {
                        let fileURL = self.tempFileManager.store(data: data)
                        let asset = CKAsset(fileURL: fileURL)
                        record[attributeName] = asset
                    } else if attributeDescription.attributeType == .transformableAttributeType,
                        let value = value,
                              let transformed = self.reverseTransformedValue(value, valueTransformerName: attributeDescription.valueTransformerName) as? CKRecordValueProtocol{
                        record[attributeName] = transformed
                    } else if let encrypted = encryptedFields,
                              encrypted.contains(attributeName) {
                        if #available(iOS 15, OSX 12, watchOS 8.0, *) {
                            record.encryptedValues[attributeName] = value as? CKRecordValueProtocol
                        }
                        // Else not possible, since the EncryptedObject protocol is only declared for CloudKit versions that support encryption
                    } else {
                        record[attributeName] = value as? CKRecordValueProtocol
                    }
                }
            })
        }
        
        let entityClass: AnyClass? = NSClassFromString(entityDescription.managedObjectClassName)
        var parentKey: String?
        if let parentKeyClass = entityClass as? ParentKey.Type {
            parentKey = parentKeyClass.parentKey()
        }
        
        let referencedEntities = referencedSyncedEntitiesByReferenceName(for: originalObject, context: context)
        referencedEntities.forEach { (relationshipName, entity) in
            if entityState == .new || changedKeys.contains(relationshipName) {
                
                if let recordProcessingDelegate = recordProcessingDelegate,
                   !recordProcessingDelegate.shouldProcessPropertyBeforeUpload(propertyName: relationshipName, object: originalObject, record: record) {
                    return
                }
                
                let recordID = CKRecord.ID(recordName: entity.identifier!, zoneID: self.recordZoneID)
                // if we set the parent we must make the action .deleteSelf, otherwise we get errors if we ever try to delete the parent record
                let action: CKRecord.Reference.Action = parentKey == relationshipName ? .deleteSelf : .none
                let recordReference = CKRecord.Reference(recordID: recordID, action: action)
                record[relationshipName] = recordReference
            }
        }
        
        if let parentKey = parentKey,
            (entityState == .new || changedKeys.contains(parentKey)),
            let reference = record[parentKey] as? CKRecord.Reference {
            // For the parent reference we have to use action .none though, even if we must use .deleteSelf for the attribute (see ^)
            record.parent = CKRecord.Reference(recordID: reference.recordID, action: CKRecord.Reference.Action.none)
            parentEntity = referencedEntities[parentKey]
        }
        
        record[CoreDataAdapter.timestampKey] = entity.updatedDate
        
        return record
    }
    
    func referencedSyncedEntitiesByReferenceName(for object: NSManagedObject, context: NSManagedObjectContext) -> [String: QSSyncedEntity] {
        var objectIDsByRelationshipName: [String: PrimaryKeyValue]!
        context.performAndWait {
            objectIDsByRelationshipName = self.referencedObjectIdentifiersByRelationshipName(for: object)
        }
        
        var entitiesByName = [String: QSSyncedEntity]()
        objectIDsByRelationshipName.forEach { (relationshipName, identifier) in
            if let entity = self.syncedEntity(withOriginIdentifier: identifier) {
                entitiesByName[relationshipName] = entity
            }
        }
        return entitiesByName
    }
    
    func referencedObjectIdentifiersByRelationshipName(for object: NSManagedObject) -> [String: PrimaryKeyValue] {
        var objectIDs = [String: PrimaryKeyValue]()
        object.entity.relationshipsByName.forEach { (name, relationshipDescription) in
            if !relationshipDescription.isToMany,
                let referencedObject = object.value(forKey: name) as? NSManagedObject {
                objectIDs[relationshipDescription.name] = self.uniqueIdentifier(for: referencedObject)
            }
        }
        return objectIDs
    }
}

// MARK: - Target context
extension CoreDataAdapter {
    func insertManagedObject(entityName: String) -> NSManagedObject {
        let managedObject = NSEntityDescription.insertNewObject(forEntityName: entityName,
                                                                into: targetImportContext)
        try! targetImportContext.obtainPermanentIDs(for: [managedObject])
        return managedObject
    }
    
    func managedObjects(entityName: String, identifiers: [PrimaryKeyValue], context: NSManagedObjectContext) -> [NSManagedObject] {
        let identifierKey = identifierFieldName(forEntity: entityName)
        return try! context.executeFetchRequest(entityName: entityName,
                                                predicate: NSPredicate(format: "%K IN %@", identifierKey, identifiers.map { $0.value })) as! [NSManagedObject]
    }
    
    func managedObject(entityName: String, identifier: PrimaryKeyValue, context: NSManagedObjectContext) -> NSManagedObject? {
        let identifierKey = identifierFieldName(forEntity: entityName)
        return try? context.executeFetchRequest(entityName: entityName,
                                                predicate: NSPredicate(format: "%K == %@", identifierKey, identifier.value)).first as? NSManagedObject
    }
    
    func applyAttributeChanges(record: CKRecord, to object: NSManagedObject, state: SyncedEntityState, changedKeys: [String]) {
        let primaryKey = identifierFieldName(forEntity: object.entity.name!)
        if state == .changed || state == .new {
            switch mergePolicy {
            case .server:
                object.entity.attributesByName.forEach { (attributeName, attributeDescription) in
                    if !shouldIgnore(key: attributeName) && !(record[attributeName] is CKRecord.Reference) && primaryKey != attributeName {
                        assignAttributeInRecord(record,
                                                toManagedObject: object,
                                                attributeName: attributeName,
                                                attributeDescription: attributeDescription)
                    }
                }
            case .client:
                object.entity.attributesByName.forEach { (attributeName, attributeDescription) in
                    if !shouldIgnore(key: attributeName) && !(record[attributeName] is CKRecord.Reference) && primaryKey != attributeName && !changedKeys.contains(attributeName) && state != .new {
                        assignAttributeInRecord(record,
                                                toManagedObject: object,
                                                attributeName: attributeName,
                                                attributeDescription: attributeDescription)
                    }
                }
            case .custom:
                if let conflictDelegate = conflictDelegate {
                    var recordChanges = [String: Any]()
                    object.entity.attributesByName.forEach { (attributeName, attributeDescription) in
                        if !(record[attributeName] is CKRecord.Reference) && primaryKey != attributeName {
                            if let asset = record[attributeName] as? CKAsset {
                                if let url = asset.fileURL,
                                    let data = try? Data(contentsOf: url) {
                                    recordChanges[attributeName] = data
                                }
                            } else if let value = record[attributeName] {
                                recordChanges[attributeName] = value
                            } else {
                                recordChanges[attributeName] = NSNull()
                            }
                        }
                    }
                    conflictDelegate.coreDataAdapter(self, gotChanges: recordChanges, for: object)
                }
            }
        } else {
            object.entity.attributesByName.forEach { (attributeName, attributeDescription) in
                if !shouldIgnore(key: attributeName) && !(record[attributeName] is CKRecord.Reference) && primaryKey != attributeName {
                    assignAttributeInRecord(record,
                                            toManagedObject: object,
                                            attributeName: attributeName,
                                            attributeDescription: attributeDescription)
                }
            }
        }
    }
    
    func assignAttributeInRecord(_ record: CKRecord, toManagedObject object: NSManagedObject, attributeName: String, attributeDescription: NSAttributeDescription) {
        
        if let recordProcessingDelegate = recordProcessingDelegate,
           !recordProcessingDelegate.shouldProcessPropertyInDownload(propertyName: attributeName, object: object, record: record) {
            return
        }
        
        let encryptedFields = entityEncryptedFields[object.entity.name!]
        
        if let encrypted = encryptedFields,
           encrypted.contains(attributeName) {
            if #available(iOS 15, OSX 12, watchOS 8.0, *) {
                object.setValue(record.encryptedValues[attributeName], forKey: attributeName)
            }
            // Else not possible, since the EncryptedObject protocol is only declared for CloudKit versions that support encryption
        } else {
            let value = record[attributeName]
            if let value = value as? CKAsset {
                guard let url = value.fileURL,
                      let data = try? Data(contentsOf: url) else { return }
                object.setValue(data, forKey: attributeName)
            } else if let value = value,
                      attributeDescription.attributeType == .transformableAttributeType {
                object.setValue(transformedValue(value,
                                                 valueTransformerName: attributeDescription.valueTransformerName),
                                forKey: attributeName)
            } else {
                object.setValue(value, forKey: attributeName)
            }
        }
    }
    
    func mergeChangesIntoTargetContext(completion: (Error?)->()) {
        debugPrint("Requesting save")
        delegate.coreDataAdapter(self, requestsContextSaveWithCompletion: { (error) in
            guard error == nil else {
                completion(error)
                return
            }
            
            self.isMergingImportedChanges = true
            debugPrint("Now importing")
            self.delegate.coreDataAdapter(self, didImportChanges: self.targetImportContext, completion: { (error) in
                self.isMergingImportedChanges = false
                debugPrint("Saved imported changes")
                completion(error)
            })
        })
    }
    
    func childrenRecords(for entity: QSSyncedEntity) -> [CKRecord] {
        // Add record for this entity
        var childrenRecords = [CKRecord]()
        var parent: QSSyncedEntity?
        childrenRecords.append(self.recordToUpload(for: entity, context: targetContext, parentEntity: &parent))
        
        let relationships = childrenRelationships[entity.entityType!] ?? []
        for relationship in relationships {
            // get child objects using parentkey
            let objectID = self.getObjectIdentifier(for: entity)!
            let entityType = entity.entityType!
            var originalObject: NSManagedObject!
            var childrenIdentifiers = [PrimaryKeyValue]()
            targetContext.performAndWait {
                originalObject = self.managedObject(entityName: entityType, identifier: objectID, context: self.targetContext)
                let childrenObjects = self.children(of: originalObject, relationship: relationship)
                childrenIdentifiers.append(contentsOf: childrenObjects.compactMap { self.uniqueIdentifier(for: $0) })
            }
            // get their syncedEntities
            for identifier in childrenIdentifiers {
                if let childEntity = self.syncedEntity(withOriginIdentifier: identifier) {
                    // add and also add their children
                    childrenRecords.append(contentsOf: self.childrenRecords(for: childEntity))
                }
            }
        }
        
        return childrenRecords
    }
    
    func children(of parent: NSManagedObject, relationship: ChildRelationship) -> [NSManagedObject] {
        let predicate = NSPredicate(format: "%K == %@", relationship.childParentKey, parent)
        return (try? parent.managedObjectContext?.executeFetchRequest(entityName: relationship.childEntityName, predicate: predicate) as? [NSManagedObject]) ?? []
    }
}

// MARK: - Pending relationships
extension CoreDataAdapter {
    func prepareRelationshipChanges(for object: NSManagedObject, record: CKRecord) -> [String] {
        var relationships = [String]()
        for relationshipName in object.entity.relationshipsByName.keys {
            if object.entity.relationshipsByName[relationshipName]!.isToMany {
                continue
            }
            
            if record[relationshipName] != nil {
                relationships.append(relationshipName)
            } else {
                object.setValue(nil, forKey: relationshipName)
            }
        }
        return relationships
    }
    
    func saveRelationshipChanges(record: CKRecord, names: [String], entity: QSSyncedEntity) {
        for key in names {
            if let reference = record[key] as? CKRecord.Reference {
                let relationship = QSPendingRelationship(entity: NSEntityDescription.entity(forEntityName: "QSPendingRelationship", in: privateContext)!,
                                                         insertInto: privateContext)
                relationship.relationshipName = key
                relationship.targetIdentifier = reference.recordID.recordName
                relationship.forEntity = entity
            }
        }
    }
    
    func saveShareRelationship(for entity: QSSyncedEntity, record: CKRecord) {
        if let share = record.share {
            let relationship = QSPendingRelationship(entity: NSEntityDescription.entity(forEntityName: "QSPendingRelationship", in: privateContext)!,
                                                     insertInto: privateContext)
            relationship.relationshipName = "share"
            relationship.targetIdentifier = share.recordID.recordName
            relationship.forEntity = entity
        }
    }
    
    func entitiesWithPendingRelationships() -> [QSSyncedEntity] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: "QSSyncedEntity", in: privateContext)!
        fetchRequest.resultType = .managedObjectResultType
        fetchRequest.predicate = NSPredicate(format: "pendingRelationships.@count != 0")
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.relationshipKeyPathsForPrefetching = ["originIdentifier", "pendingRelationships"]
        return try! privateContext.fetch(fetchRequest) as! [QSSyncedEntity]
    }
    
    func pendingShareRelationship(for entity: QSSyncedEntity) -> QSPendingRelationship? {
        
        return (entity.pendingRelationships as? Set<QSPendingRelationship>)?.first {
            $0.relationshipName ?? "" == "share"
        }
    }
    
    func originObjectIdentifier(forEntityWithIdentifier identifier: String) -> RelationshipTarget? {
        guard let result = try? privateContext.executeFetchRequest(entityName: "QSSyncedEntity",
                                                       predicate: NSPredicate(format: "identifier == %@", identifier),
                                                       fetchLimit: 1,
                                                       resultType: .dictionaryResultType,
                                                       propertiesToFetch: ["originObjectID", "entityType"]).first,
              let dictionary = result as? [String: String],
              let stringId = dictionary["originObjectID"],
              let entityType = dictionary["entityType"] else {
            return nil
        }
        
        return RelationshipTarget(originObjectID: self.getObjectIdentifier(stringObjectId: stringId, entityType: entityType), entityType: entityType)
    }
    
    func pendingRelationshipTargetIdentifiers(for entity: QSSyncedEntity) -> [String: RelationshipTarget] {
        guard let pending = entity.pendingRelationships as? Set<QSPendingRelationship> else { return [:] }
        var relationships = [String: RelationshipTarget]()
        
        for pendingRelationship in pending {
            if pendingRelationship.relationshipName == "share" {
                continue
            }
            
            if let targetObjectInfo = originObjectIdentifier(forEntityWithIdentifier: pendingRelationship.targetIdentifier!) {
                relationships[pendingRelationship.relationshipName!] = targetObjectInfo
            }
        }
        return relationships
    }
    
    func applyPendingRelationships() {
        
        //Need to save before we can use NSDictionaryResultType, which greatly speeds up this step
        self.savePrivateContext()
        
        let entities = entitiesWithPendingRelationships()
        var queriesByEntityType = [String: [PrimaryKeyValue: QueryData]]()
        for entity in entities {
            
            guard entity.entityState != .deleted else { continue }
            
            var pendingCount = entity.pendingRelationships?.count ?? 0
            if let pendingShare = pendingShareRelationship(for: entity) {
                let share = syncedEntity(withIdentifier: pendingShare.targetIdentifier!)
                entity.share = share
                pendingCount = pendingCount - 1
            }
            
            // If there was something to connect, other than the share
            if pendingCount > 0 {
                let key = getObjectIdentifier(for: entity)!
                let query = QueryData(identifier: key,
                                      record: nil,
                                      entityType: entity.entityType!,
                                      changedKeys: entity.changedKeysArray,
                                      state: entity.entityState,
                                      targetRelationshipsDictionary: pendingRelationshipTargetIdentifiers(for: entity))
                if queriesByEntityType[entity.entityType!] == nil {
                    queriesByEntityType[entity.entityType!] = [PrimaryKeyValue: QueryData]()
                }
                queriesByEntityType[entity.entityType!]![key] = query
            }
            
            (entity.pendingRelationships as? Set<QSPendingRelationship>)?.forEach {
                self.privateContext.delete($0)
            }
        }
        
        // Might not need to dispatch if there's nothing to connect
        guard queriesByEntityType.count > 0 else { return }
        
        targetImportContext.performAndWait {
            self.targetApply(pendingRelationships: queriesByEntityType, context: self.targetImportContext)
        }
    }
    
    func targetApply(pendingRelationships: [String: [PrimaryKeyValue: QueryData]], context: NSManagedObjectContext) {
        debugPrint("Target apply pending relationships")
        
        pendingRelationships.forEach { (entityType, queries) in
            
            let objects = self.managedObjects(entityName: entityType,
                                              identifiers: Array(queries.keys),
                                              context: context)
            for managedObject in objects {
                guard let identifier = self.uniqueIdentifier(for: managedObject),
                    let query = queries[identifier] else { continue }
                query.targetRelationshipsDictionary?.forEach({ (relationshipName, target) in
                    let shouldApplyTarget = query.state.rawValue > SyncedEntityState.changed.rawValue ||
                        self.mergePolicy == .server ||
                        (self.mergePolicy == .client && (!query.changedKeys.contains(relationshipName) || (query.state == .new && managedObject.value(forKey: relationshipName) == nil)))
                    if let entityType = target.entityType,
                        let originObjectID = target.originObjectID,
                        shouldApplyTarget {
                        let targetManagedObject = self.managedObject(entityName: entityType,
                                                                     identifier: originObjectID,
                                                                     context: context)
                        managedObject.setValue(targetManagedObject, forKey: relationshipName)
                    } else if self.mergePolicy == .custom,
                        let entityType = target.entityType,
                        let originObjectID = target.originObjectID,
                        let conflictDelegate = self.conflictDelegate,
                        let targetManagedObject = self.managedObject(entityName: entityType,
                                                                     identifier: originObjectID,
                                                                     context: context) {
                        
                        conflictDelegate.coreDataAdapter(self,
                                                         gotChanges: [relationshipName: targetManagedObject],
                                                         for: managedObject)
                    }
                })
            }
        }
    }
}
