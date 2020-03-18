//
//  RealmAdapter.swift
//  Pods
//
//  Created by Manuel Entrena on 29/08/2017.
//
//

import CloudKit
import Realm

func executeOnMainQueue(_ closure: () -> ()) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.sync {
            closure()
        }
    }
}

@objc public protocol RealmAdapterDelegate {
    
    /**
     *  Asks the delegate to resolve conflicts for a managed object. The delegate is expected to examine the change dictionary and optionally apply any of those changes to the managed object.
     *
     *  @param adapter    The `QSRealmAdapter` that is providing the changes.
     *  @param changeDictionary Dictionary containing keys and values with changes for the managed object. Values can be [NSNull null] to represent a nil value.
     *  @param object           The `RLMObject` that has changed on iCloud.
     */
    func RealmAdapter(_ adapter: RealmAdapter, gotChanges changes: [String: Any], object: RLMObject)
}

struct ChildRelationship {
    
    let parentEntityName: String
    let childEntityName: String
    let childParentKey: String
}

struct RealmProvider {
    
    let persistenceRealm: RLMRealm
    let targetRealm: RLMRealm
    
    init?(persistenceConfiguration: RLMRealmConfiguration, targetConfiguration: RLMRealmConfiguration) {

        guard let persistenceRealm = try? RLMRealm(configuration: persistenceConfiguration),
            let targetRealm = try? RLMRealm(configuration: targetConfiguration) else {
                return nil
        }
        
        self.persistenceRealm = persistenceRealm
        self.targetRealm = targetRealm
    }
}

struct ObjectUpdate {
    
    enum UpdateType {
        case insertion
        case update
        case deletion
    }
    
    let object: RLMObject
    let identifier: String
    let entityType: String
    let updateType: UpdateType
    let changes: [RLMPropertyChange]?
}


@objc public class RealmAdapter: NSObject, ModelAdapter {
    
    static let shareRelationshipKey = "com.syncKit.shareRelationship"
    
    @objc public let persistenceRealmConfiguration: RLMRealmConfiguration
    @objc public let targetRealmConfiguration: RLMRealmConfiguration
    @objc public let zoneID: CKRecordZone.ID
    @objc public var mergePolicy: MergePolicy = .server
    @objc public var delegate: RealmAdapterDelegate?
    @objc public var forceDataTypeInsteadOfAsset: Bool = false
    
    private lazy var tempFileManager: TempFileManager = {
        TempFileManager(identifier: "\(recordZoneID.ownerName).\(recordZoneID.zoneName)")
    }()
    
    var realmProvider: RealmProvider!
    
    var collectionNotificationTokens = [RLMNotificationToken]()
    var objectNotificationTokens = [String: RLMNotificationToken]()
    var pendingTrackingUpdates = [ObjectUpdate]()
    var childRelationships = [String: Array<ChildRelationship>]()
    var modelTypes = [String: RLMObject.Type]()
    @objc public private(set) var hasChanges = false
    
    /* Should be initialized on main queue */
    @objc public init(persistenceRealmConfiguration: RLMRealmConfiguration, targetRealmConfiguration: RLMRealmConfiguration, recordZoneID: CKRecordZone.ID) {
        
        self.persistenceRealmConfiguration = persistenceRealmConfiguration
        self.targetRealmConfiguration = targetRealmConfiguration
        self.zoneID = recordZoneID
        
        super.init()
        
        executeOnMainQueue {
            setupTypeNamesLookup()
            setup()
            setupChildrenRelationshipsLookup()
        }
    }
    
    deinit {
        invalidateRealmAndTokens()
    }
    
    func invalidateRealmAndTokens() {
        executeOnMainQueue {
            for token in objectNotificationTokens.values {
                token.invalidate()
            }
            objectNotificationTokens.removeAll()
            for token in collectionNotificationTokens {
                token.invalidate()
            }
            collectionNotificationTokens.removeAll()
            
            realmProvider?.persistenceRealm.invalidate()
            realmProvider = nil
        }
    }
    
    @objc static public func defaultPersistenceConfiguration() -> RLMRealmConfiguration {
        
        let configuration = RLMRealmConfiguration()
        configuration.schemaVersion = 1
        configuration.migrationBlock = { migration, oldSchemaVersion in
            
        }
        configuration.objectClasses = [SyncedEntity.self, Record.self, PendingRelationship.self, ServerToken.self]
        return configuration
    }
    
    func setupTypeNamesLookup() {
        
        targetRealmConfiguration.objectClasses?.forEach { objectType in
            if let realmObjectType = objectType as? RLMObject.Type {
                modelTypes[realmObjectType.className()] = realmObjectType
            }
        }
    }
    
    func setup() {
        
        realmProvider = RealmProvider(persistenceConfiguration: persistenceRealmConfiguration, targetConfiguration: targetRealmConfiguration)
        
        let needsInitialSetup = SyncedEntity.allObjects(in: realmProvider.persistenceRealm).count <= 0
        for schema in realmProvider.targetRealm.schema.objectSchema {
            
            let objectClass = realmObjectClass(name: schema.className)
            let primaryKey = objectClass.primaryKey()!
            let results = objectClass.allObjects(in: realmProvider.targetRealm)
            
            // Register for collection notifications
            let token = results.addNotificationBlock { [weak self] (results, changes, error) in

                guard let insertions = changes?.insertions,
                    let results = results else { return }

                for index in insertions {
                    guard let object = results[index.uintValue] as? RLMObject,
                        let identifier = object.value(forKey: primaryKey) as? String else { continue }
                    
                    /* This can be called during a transaction, and it's illegal to add a notification block during a transaction,
                     * so we keep all the insertions in a list to be processed as soon as the realm finishes the current transaction
                     */
                    if object.realm!.inWriteTransaction {
                        
                        self?.pendingTrackingUpdates.append(ObjectUpdate(object: object, identifier: identifier, entityType: schema.className, updateType: .insertion, changes: nil))
                    } else {
                        
                        self?.updateTracking(insertedObject: object, identifier: identifier, entityName: schema.className, provider: self!.realmProvider)
                    }
                }
            }
            collectionNotificationTokens.append(token)
            
            // Register for object updates
            for object in results {
                
                let identifier = object.value(forKey: primaryKey) as! String
                let token = object.addNotificationBlock { [weak self] (deleted, changes, error) in
                    if deleted {
                        if object.realm!.inWriteTransaction {
                            
                            self?.pendingTrackingUpdates.append(ObjectUpdate(object: object, identifier: identifier, entityType: schema.className, updateType: .deletion, changes: nil))
                        } else {
                            
                            self?.updateTracking(objectIdentifier: identifier, entityName: schema.className, inserted: false, deleted: true, changes: nil, realmProvider: self!.realmProvider)
                        }
                    } else if error == nil,
                        let propertyChanges = changes {
                        if object.realm!.inWriteTransaction {
                            
                            self?.pendingTrackingUpdates.append(ObjectUpdate(object: object, identifier: identifier, entityType: schema.className, updateType: .update, changes: propertyChanges))
                        } else {
                            
                            self?.updateTracking(objectIdentifier: identifier, entityName: schema.className, inserted: false, deleted: false, changes: propertyChanges, realmProvider: self!.realmProvider)
                        }
                    }
                }
                
                if needsInitialSetup {
                    
                    createSyncedEntity(entityType: schema.className, identifier: identifier, realm: realmProvider.persistenceRealm)
                }
                
                objectNotificationTokens[identifier] = token
            }
        }
        
        let token = realmProvider.targetRealm.addNotificationBlock { [weak self](_, _) in
            self?.enqueueObjectUpdates()
        }
        collectionNotificationTokens.append(token)
        
        updateHasChanges(realm: realmProvider.persistenceRealm)
        
        if hasChanges {
            
            NotificationCenter.default.post(name: .ModelAdapterHasChangesNotification, object: self)
        }
    }
    
    func realmObjectClass(name: String) -> RLMObject.Type {
        
        return modelTypes[name]!
    }
    
    func updateHasChanges(realm: RLMRealm) {
        
        let predicate = NSPredicate(format: "state != %ld", SyncedEntityState.synced.rawValue)
        let results = SyncedEntity.objects(in: realm, with: predicate)
        
        hasChanges = results.count > 0;
    }
    
    func setupChildrenRelationshipsLookup() {
        
        childRelationships.removeAll()
        
        for objectSchema in realmProvider.targetRealm.schema.objectSchema {
            
            let objectClass = realmObjectClass(name: objectSchema.className)
            if let parentClass = objectClass.self as? ParentKey.Type {
                let parentKey = parentClass.parentKey()
                let parentProperty = objectSchema.properties.first { $0.name == parentKey }
                
                let parentClassName = parentProperty!.objectClassName!
                let relationship = ChildRelationship(parentEntityName: parentClassName, childEntityName: objectSchema.className, childParentKey: parentKey)
                if childRelationships[parentClassName] == nil {
                    childRelationships[parentClassName] = Array<ChildRelationship>()
                }
                childRelationships[parentClassName]!.append(relationship)
            }
        }
    }
    
    func enqueueObjectUpdates() {
        
        if pendingTrackingUpdates.count > 0 {
            
            if realmProvider.targetRealm.inWriteTransaction {
                
                DispatchQueue.main.async { [weak self] in
                    self?.enqueueObjectUpdates()
                }
            } else {
                
                updateObjectTracking()
            }
        }
    }
    
    func updateObjectTracking() {
        
        for update in pendingTrackingUpdates {
            
            if update.updateType == .insertion {
                
                updateTracking(insertedObject: update.object, identifier: update.identifier, entityName: update.entityType, provider: realmProvider)
            } else {
                
                updateTracking(objectIdentifier: update.identifier, entityName: update.entityType, inserted: false, deleted: (update.updateType == .deletion), changes: update.changes, realmProvider: realmProvider)
            }
        }
        
        pendingTrackingUpdates.removeAll()
    }
    
    func updateTracking(insertedObject: RLMObject, identifier: String, entityName: String, provider: RealmProvider) {
        
        let token = insertedObject.addNotificationBlock { [weak self] (deleted, changes, error) in
            if deleted {
                self?.updateTracking(objectIdentifier: identifier, entityName: entityName, inserted: false, deleted: true, changes: nil, realmProvider: self!.realmProvider)
            } else if let propertyChanges = changes {
                self?.updateTracking(objectIdentifier: identifier, entityName: entityName, inserted: false, deleted: false, changes: propertyChanges, realmProvider: provider)
            }
        }
        
        objectNotificationTokens[identifier] = token
        
        updateTracking(objectIdentifier: identifier, entityName: entityName, inserted: true, deleted: false, changes: nil, realmProvider: provider)
    }
    
    func updateTracking(objectIdentifier: String, entityName: String, inserted: Bool, deleted: Bool, changes: [RLMPropertyChange]?, realmProvider: RealmProvider) {
        
        var isNewChange = false
        let identifier = "\(entityName).\(objectIdentifier)"
        let syncedEntity = getSyncedEntity(objectIdentifier: identifier, realm: realmProvider.persistenceRealm)
        
        if deleted {
            
            isNewChange = true
            
            if let syncedEntity = syncedEntity {
                realmProvider.persistenceRealm.beginWriteTransaction()
                syncedEntity.state = SyncedEntityState.deleted.rawValue
                try? realmProvider.persistenceRealm.commitWriteTransaction()
            }
            
            if let token = objectNotificationTokens[objectIdentifier] {
                
                objectNotificationTokens.removeValue(forKey: objectIdentifier)
                token.invalidate()
            }
            
        } else if syncedEntity == nil {
            
            createSyncedEntity(entityType: entityName, identifier: objectIdentifier, realm: realmProvider.persistenceRealm)
            
            if inserted {
                isNewChange = true
            }
            
        } else if !inserted {
            
            guard let syncedEntity = syncedEntity else {
                return
            }
            
            isNewChange = true
            
            var changedKeys: NSMutableSet
            if let changedKeysString = syncedEntity.changedKeys {
                changedKeys = NSMutableSet(array: changedKeysString.components(separatedBy: ","))
            } else {
                changedKeys = NSMutableSet()
            }
            
            if let changes = changes {
                for propertyChange in changes {
                    
                    changedKeys.add(propertyChange.name)
                }
            }
            
            realmProvider.persistenceRealm.beginWriteTransaction()
            syncedEntity.changedKeys = (changedKeys.allObjects as! [String]).joined(separator: ",")
            if syncedEntity.state == SyncedEntityState.synced.rawValue && !syncedEntity.changedKeys!.isEmpty {
                syncedEntity.state = SyncedEntityState.changed.rawValue
                // If state was New then leave it as that
            }
            try? realmProvider.persistenceRealm.commitWriteTransaction()
        }
        
        if !hasChanges && isNewChange {
            hasChanges = true
            NotificationCenter.default.post(name: .ModelAdapterHasChangesNotification, object: self)
        }
    }
    
    func commitTargetWriteTransactionWithoutNotifying() {
        
        try? realmProvider.targetRealm.commitWriteTransactionWithoutNotifying(Array(objectNotificationTokens.values))
    }
    
    @discardableResult
    func createSyncedEntity(entityType: String, identifier: String, realm: RLMRealm) -> SyncedEntity {
        
        let syncedEntity = SyncedEntity(entityType: entityType, identifier: "\(entityType).\(identifier)", state: SyncedEntityState.new.rawValue)
        
        realm.beginWriteTransaction()
        realm.add(syncedEntity)
        try? realm.commitWriteTransaction()
        
        return syncedEntity
    }
    
    func createSyncedEntity(record: CKRecord, realmProvider: RealmProvider) -> SyncedEntity {
        
        let syncedEntity = SyncedEntity(entityType: record.recordType, identifier: record.recordID.recordName, state: SyncedEntityState.synced.rawValue)
        
        realmProvider.persistenceRealm.add(syncedEntity)
        
        let objectClass = realmObjectClass(name: record.recordType)
        let primaryKey = objectClass.primaryKey()!
        let objectIdentifier = getObjectIdentifier(for: syncedEntity)
        let object = objectClass.init()
        object.setValue(objectIdentifier, forKey: primaryKey)
        realmProvider.targetRealm.add(object)
        
        return syncedEntity;

    }
    
    func getObjectIdentifier(for syncedEntity: SyncedEntity) -> String {
        
        let range = syncedEntity.identifier.range(of: syncedEntity.entityType)!
        let index = syncedEntity.identifier.index(range.upperBound, offsetBy: 1)
        return String(syncedEntity.identifier[index...])
    }
    
    func syncedEntity(for object: RLMObject, realm: RLMRealm) -> SyncedEntity? {
        
        let objectClass = realmObjectClass(name: object.objectSchema.className)
        let primaryKey = objectClass.primaryKey()!
        let identifier = object.objectSchema.className + "." + (object.value(forKey: primaryKey) as! String)
        return getSyncedEntity(objectIdentifier: identifier, realm: realm)
    }
    
    func getSyncedEntity(objectIdentifier: String, realm: RLMRealm) -> SyncedEntity? {
        
        return SyncedEntity.object(in: realm, forPrimaryKey: objectIdentifier)
    }
    
    func shouldIgnore(key: String) -> Bool {
        
        return CloudKitSynchronizer.metadataKeys.contains(key)
    }
    
    func applyChanges(in record: CKRecord, to object: RLMObject, syncedEntity: SyncedEntity, realmProvider: RealmProvider) {
        
        if syncedEntity.state == SyncedEntityState.changed.rawValue || syncedEntity.state == SyncedEntityState.new.rawValue {
        
            if mergePolicy == .server {
                
                for property in object.objectSchema.properties {
                    if shouldIgnore(key: property.name) {
                        continue
                    }
                    if property.array || property.type == RLMPropertyType.linkingObjects {
                        continue
                    }
                    
                    applyChange(property: property.name, record: record, object: object, syncedEntity: syncedEntity, realmProvider: realmProvider)
                }
                
            } else if mergePolicy == .client {
                
                let changedKeys: [String] = syncedEntity.changedKeys?.components(separatedBy: ",") ?? []
                
                for property in object.objectSchema.properties {
                    
                    if property.array || property.type == RLMPropertyType.linkingObjects {
                        continue
                    }
                    
                    if !shouldIgnore(key: property.name) &&
                    !changedKeys.contains(property.name) &&
                        syncedEntity.state != SyncedEntityState.new.rawValue {
                        
                        applyChange(property: property.name, record: record, object: object, syncedEntity: syncedEntity, realmProvider: realmProvider)
                    }
                }
                
            } else if mergePolicy == .custom {
                
                var recordChanges = [String: Any]()
                
                for property in object.objectSchema.properties {
                    
                    if property.array || property.type == RLMPropertyType.linkingObjects {
                        continue
                    }
                    
                    if !shouldIgnore(key: property.name) &&
                        !(record[property.name] is CKRecord.Reference) {

                        if let asset = record[property.name] as? CKAsset {
                            recordChanges[property.name] = asset.fileURL != nil ? NSData(contentsOf: asset.fileURL!) : NSNull()
                        } else {
                            recordChanges[property.name] = record[property.name] ?? NSNull()
                        }
                    }
                }
                
                delegate?.RealmAdapter(self, gotChanges: recordChanges, object: object)
                
            }
        } else {
            
            for property in object.objectSchema.properties {
                
                if shouldIgnore(key: property.name) {
                    continue
                }
                if property.array || property.type == RLMPropertyType.linkingObjects {
                    continue
                }
                
                applyChange(property: property.name, record: record, object: object, syncedEntity: syncedEntity, realmProvider: realmProvider)
            }
        }
    }
    
    func applyChange(property key: String, record: CKRecord, object: RLMObject, syncedEntity: SyncedEntity, realmProvider: RealmProvider) {
        
        if key == object.objectSchema.primaryKeyProperty!.name {
            return
        }
        
        let value = record[key]
        if let reference = value as? CKRecord.Reference {
            // Save relationship to be applied after all records have been downloaded and persisted
            // to ensure target of the relationship has already been created
            let recordName = reference.recordID.recordName
            let separatorRange = recordName.range(of: ".")!
            let objectIdentifier = String(recordName[separatorRange.upperBound...])
            savePendingRelationship(name: key, syncedEntity: syncedEntity, targetIdentifier: objectIdentifier, realm: realmProvider.persistenceRealm)
        } else if let asset = value as? CKAsset {
            if let fileURL = asset.fileURL,
                let data =  NSData(contentsOf: fileURL) {
                object.setValue(data, forKey: key)
            }
        } else {
            // If property is not a relationship or property is nil
            object.setValue(value, forKey: key)
        }
    }
    
    func savePendingRelationship(name: String, syncedEntity: SyncedEntity, targetIdentifier: String, realm: RLMRealm) {
        
        let pendingRelationship = PendingRelationship()
        pendingRelationship.relationshipName = name
        pendingRelationship.forSyncedEntity = syncedEntity
        pendingRelationship.targetIdentifier = targetIdentifier
        realm.add(pendingRelationship)
    }
    
    func saveShareRelationship(for entity: SyncedEntity, record: CKRecord) {
        
        if let share = record.share {
            let relationship = PendingRelationship()
            relationship.relationshipName = RealmAdapter.shareRelationshipKey
            relationship.targetIdentifier = share.recordID.recordName
            relationship.forSyncedEntity = entity
            entity.realm?.add(relationship)
        }
    }
    
    func applyPendingRelationships(realmProvider: RealmProvider) {
        
        let pendingRelationships = PendingRelationship.allObjects(in: realmProvider.persistenceRealm)
        
        if pendingRelationships.count == 0 {
            return
        }
        
        realmProvider.persistenceRealm.beginWriteTransaction()
        realmProvider.targetRealm.beginWriteTransaction()
        for object in pendingRelationships {
            let relationship = object as! PendingRelationship
            let entity = relationship.forSyncedEntity
            
            guard let syncedEntity = entity,
                syncedEntity.entityState != .deleted else { continue }
            
            let originObjectClass = realmObjectClass(name: syncedEntity.entityType)
            let objectIdentifier = getObjectIdentifier(for: syncedEntity)
            guard let originObject = originObjectClass.object(in: realmProvider.targetRealm, forPrimaryKey: objectIdentifier) else { continue }
            
            if relationship.relationshipName == RealmAdapter.shareRelationshipKey {
                syncedEntity.share = getSyncedEntity(objectIdentifier: relationship.targetIdentifier, realm: realmProvider.persistenceRealm)
                realmProvider.persistenceRealm.delete(relationship)
                continue;
            }
            
            var targetClassName: String?
            for property in originObject.objectSchema.properties {
                if property.name == relationship.relationshipName {
                    targetClassName = property.objectClassName
                    break
                }
            }
            
            guard let className = targetClassName else {
                continue
            }
            
            let targetObjectClass = realmObjectClass(name: className)
            let targetObject = targetObjectClass.object(in: realmProvider.targetRealm, forPrimaryKey: relationship.targetIdentifier)
            
            guard let target = targetObject else {
                continue
            }
            originObject.setValue(target, forKey: relationship.relationshipName)
            
            realmProvider.persistenceRealm.delete(relationship)
        }
        
        try? realmProvider.persistenceRealm.commitWriteTransaction()
        commitTargetWriteTransactionWithoutNotifying()
    }
    
    func save(record: CKRecord, for syncedEntity: SyncedEntity) {
        
        if syncedEntity.record == nil {
            syncedEntity.record = Record()
        }
        
        syncedEntity.record!.encodedRecord = encodedRecord(record, onlySystemFields: true)
    }
    
    func encodedRecord(_ record: CKRecord, onlySystemFields: Bool) -> Data {
        
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        if onlySystemFields {
            record.encodeSystemFields(with: archiver)
        } else {
            record.encode(with: archiver)
        }
        archiver.finishEncoding()
        return data as Data
    }
    
    func getRecord(for syncedEntity: SyncedEntity) -> CKRecord? {
        
        var record: CKRecord?
        if let recordData = syncedEntity.record?.encodedRecord {
            let unarchiver = NSKeyedUnarchiver(forReadingWith: recordData)
            record = CKRecord(coder: unarchiver)
            unarchiver.finishDecoding()
        }
        return record
    }
    
    func save(share: CKShare, forSyncedEntity entity: SyncedEntity, realmProvider: RealmProvider) {
        
        var qsRecord: Record?
        if let entityForShare = entity.share {
            qsRecord = entityForShare.record
        } else {
            let entityForShare = createSyncedEntity(for: share, realmProvider: realmProvider)
            qsRecord = Record()
            realmProvider.persistenceRealm.add(qsRecord!)
            entityForShare.record = qsRecord
            entity.share = entityForShare
        }
        
        qsRecord?.encodedRecord = encodedRecord(share, onlySystemFields: false)
    }
    
    func getShare(for entity: SyncedEntity) -> CKShare? {
        
        if let recordData = entity.share?.record?.encodedRecord {
            let unarchiver = NSKeyedUnarchiver(forReadingWith: recordData)
            let share = CKShare(coder: unarchiver)
            unarchiver.finishDecoding()
            return share
        } else {
            return nil
        }
    }
    
    func createSyncedEntity(for share: CKShare, realmProvider: RealmProvider) -> SyncedEntity {
        
        let entityForShare = SyncedEntity()
        entityForShare.entityType = "CKShare"
        entityForShare.identifier = share.recordID.recordName
        entityForShare.updated = Date()
        entityForShare.state = SyncedEntityState.synced.rawValue
        realmProvider.persistenceRealm.add(entityForShare)
        
        return entityForShare
    }
    
    func nextStateToSync(after state: SyncedEntityState) -> SyncedEntityState {
        return SyncedEntityState(rawValue: state.rawValue + 1)!
    }
    
    func recordsToUpload(withState state: SyncedEntityState, limit: Int, realmProvider: RealmProvider) -> [CKRecord] {
        
        let predicate = NSPredicate(format: "state == %ld", state.rawValue)
        let results = SyncedEntity.objects(in: realmProvider.persistenceRealm, with: predicate)
        var resultArray = [CKRecord]()
        var includedEntityIDs = Set<String>()
        for object in results {
            let syncedEntity = object as! SyncedEntity
            if resultArray.count > limit {
                break
            }
            
            var entity: SyncedEntity! = syncedEntity
            while entity != nil && entity.state == state.rawValue && !includedEntityIDs.contains(entity.identifier) {
                var parentEntity: SyncedEntity? = nil
                let record = recordToUpload(syncedEntity: entity, realmProvider: realmProvider, parentSyncedEntity: &parentEntity)
                resultArray.append(record)
                includedEntityIDs.insert(entity.identifier)
                entity = parentEntity
            }
        }
        
        return resultArray
    }
    
    func recordToUpload(syncedEntity: SyncedEntity, realmProvider: RealmProvider, parentSyncedEntity: inout SyncedEntity?) -> CKRecord {
        
        let record = getRecord(for: syncedEntity) ?? CKRecord(recordType: syncedEntity.entityType, recordID: CKRecord.ID(recordName: syncedEntity.identifier, zoneID: zoneID))
        
        let objectClass = realmObjectClass(name: syncedEntity.entityType)
        let objectIdentifier = getObjectIdentifier(for: syncedEntity)
        let object = objectClass.object(in: realmProvider.targetRealm, forPrimaryKey: objectIdentifier)
        let entityState = syncedEntity.state
        
        let changedKeys = (syncedEntity.changedKeys ?? "").components(separatedBy: ",")
        
        var parentKey: String?
        if let childObject = object as? ParentKey {
            parentKey = type(of: childObject).parentKey()
        }
        
        var parent: RLMObject? = nil
        
        for property in object!.objectSchema.properties {
            
            if property.type == RLMPropertyType.object &&
                (entityState == SyncedEntityState.new.rawValue || changedKeys.contains(property.name)) {
                
                if let target = object?.value(forKey: property.name) as? RLMObject {
                    
                    let targetIdentifier = target.value(forKey: objectClass.primaryKey()!) as! String
                    let referenceIdentifier = "\(property.objectClassName!).\(targetIdentifier)"
                    let recordID = CKRecord.ID(recordName: referenceIdentifier, zoneID: zoneID)
                    // if we set the parent we must make the action .deleteSelf, otherwise we get errors if we ever try to delete the parent record
                    let action: CKRecord.Reference.Action = parentKey == property.name ? .deleteSelf : .none
                    let recordReference = CKRecord.Reference(recordID: recordID, action: action)
                    record[property.name] = recordReference;
                    if parentKey == property.name {
                        parent = target
                    }
                }
                
            } else if !property.array &&
            property.type != RLMPropertyType.linkingObjects &&
            !(property.name == objectClass.primaryKey()!) &&
                (entityState == SyncedEntityState.new.rawValue || changedKeys.contains(property.name)) {
                
                let value = object!.value(forKey: property.name)
                if property.type == RLMPropertyType.data,
                    let data = value as? Data,
                    forceDataTypeInsteadOfAsset == false  {
                    
                    let fileURL = self.tempFileManager.store(data: data)
                    let asset = CKAsset(fileURL: fileURL)
                    record[property.name] = asset
                } else if value == nil {
                    record[property.name] = nil
                } else if let recordValue = value as? CKRecordValue {
                    record[property.name] = recordValue
                }
            }
        }
        
        if let parentKey = parentKey,
            entityState == SyncedEntityState.new.rawValue || changedKeys.contains(parentKey),
            let reference = record[parentKey] as? CKRecord.Reference {
            
            record.parent = CKRecord.Reference(recordID: reference.recordID, action: .none)
            if let parent = parent {
                parentSyncedEntity = self.syncedEntity(for: parent, realm: realmProvider.persistenceRealm)
            }
        }
        
        return record;
    }
    
    // MARK: - Children records
    
    func childrenRecords(for syncedEntity: SyncedEntity) -> [CKRecord] {

        var records = [CKRecord]()
        var parent: SyncedEntity?
        records.append(recordToUpload(syncedEntity: syncedEntity, realmProvider: realmProvider, parentSyncedEntity: &parent))
        
        if let relationships = childRelationships[syncedEntity.entityType] {
            for relationship in relationships {
                
                let objectID = getObjectIdentifier(for: syncedEntity)
                let objectClass = realmObjectClass(name: syncedEntity.entityType) as RLMObject.Type
                if let object = objectClass.object(in: realmProvider.targetRealm, forPrimaryKey: objectID) {
                    
                    // Get children
                    let childObjectClass = realmObjectClass(name: relationship.childEntityName)
                    let predicate = NSPredicate(format: "%K == %@", relationship.childParentKey, object)
                    let children = childObjectClass.objects(in: realmProvider.targetRealm, with: predicate)
                    
                    for child in children {
                        if let childEntity = self.syncedEntity(for: child, realm: realmProvider.persistenceRealm) {
                            records.append(contentsOf: childrenRecords(for: childEntity))
                        }
                    }
                }
            }
        }
        
        return records
    }
    
//    - (RLMResults *)childrenOf:(RLMObject *)parent withRelationship:(QSChildRelationship *)relationship
//    {
//    Class objectClass = NSClassFromString(relationship.childEntityName);
//    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", relationship.childParentKey, parent];
//    return [objectClass objectsInRealm:parent.realm withPredicate:predicate];
//    }
    
    // MARK: - QSModelAdapter
    
    public func prepareToImport() {
        
    }
    
    public func saveChanges(in records: [CKRecord]) {
        
        guard records.count != 0,
            realmProvider != nil else {
            return
        }
        
        executeOnMainQueue {
            self.realmProvider.persistenceRealm.beginWriteTransaction()
            self.realmProvider.targetRealm .beginWriteTransaction()
            
            for record in records {
                
                var syncedEntity: SyncedEntity! = getSyncedEntity(objectIdentifier: record.recordID.recordName, realm: self.realmProvider.persistenceRealm)
                if syncedEntity == nil {
                    if #available(iOS 10.0, *) {
                        if let share = record as? CKShare {
                            syncedEntity = createSyncedEntity(for: share, realmProvider: self.realmProvider)
                        } else {
                            syncedEntity = createSyncedEntity(record: record, realmProvider: self.realmProvider)
                        }
                    } else {
                        syncedEntity = createSyncedEntity(record: record, realmProvider: self.realmProvider)
                    }
                }
                
                if syncedEntity.entityState != .deleted && syncedEntity.entityType != "CKShare" {
                    
                    let objectClass = realmObjectClass(name: record.recordType)
                    let objectIdentifier = getObjectIdentifier(for: syncedEntity)
                    guard let object = objectClass.object(in: realmProvider.targetRealm, forPrimaryKey: objectIdentifier) else {
                        continue
                    }
                    
                    applyChanges(in: record, to: object, syncedEntity: syncedEntity, realmProvider: self.realmProvider)
                    saveShareRelationship(for: syncedEntity, record: record)
                }
                
                save(record: record, for: syncedEntity)
            }
            // Order is important here. Notifications might be delivered after targetRealm is saved and
            // it's convenient if the persistenceRealm is not in a write transaction
            try? self.realmProvider.persistenceRealm.commitWriteTransaction()
            commitTargetWriteTransactionWithoutNotifying()
        }
    }
    
    public func deleteRecords(with recordIDs: [CKRecord.ID]) {
        
        guard recordIDs.count != 0,
            realmProvider != nil else {
            return
        }
        
        executeOnMainQueue {

            self.realmProvider.persistenceRealm.beginWriteTransaction()
            self.realmProvider.targetRealm.beginWriteTransaction()
            
            for recordID in recordIDs {
                
                if let syncedEntity = getSyncedEntity(objectIdentifier: recordID.recordName, realm: self.realmProvider.persistenceRealm) {
                    
                    if syncedEntity.entityType != "CKShare" {
                        
                        let objectClass = realmObjectClass(name: syncedEntity.entityType)
                        let objectIdentifier = getObjectIdentifier(for: syncedEntity)
                        let object = objectClass.object(in: realmProvider.targetRealm, forPrimaryKey: objectIdentifier)
                        
                        if let object = object {
                            
                            if let token = objectNotificationTokens[objectIdentifier] {
                                DispatchQueue.main.async {
                                    self.objectNotificationTokens.removeValue(forKey: objectIdentifier)
                                    token.invalidate()
                                }
                            }
                            self.realmProvider.targetRealm.delete(object)
                        }
                    }
                    
                    self.realmProvider.persistenceRealm.delete(syncedEntity)
                }
            }
            
            try? self.realmProvider.persistenceRealm.commitWriteTransaction()
            self.commitTargetWriteTransactionWithoutNotifying()
        }
    }
    
    public func persistImportedChanges(completion: @escaping ((Error?) -> Void)) {
        
        guard realmProvider != nil else  {
            completion(nil)
            return
        }
        
        executeOnMainQueue {
            
            self.applyPendingRelationships(realmProvider: self.realmProvider)
        }
        
        completion(nil)
    }
    
    public func recordsToUpload(limit: Int) -> [CKRecord] {
        
        guard realmProvider != nil else { return [] }
        
        var recordsArray = [CKRecord]()
        
        executeOnMainQueue {
            
            let recordLimit = limit == 0 ? Int.max : limit
            var uploadingState = SyncedEntityState.new
            
            var innerLimit = recordLimit
            while recordsArray.count < recordLimit && uploadingState.rawValue < SyncedEntityState.deleted.rawValue {
                recordsArray.append(contentsOf: self.recordsToUpload(withState: uploadingState, limit: innerLimit, realmProvider: self.realmProvider))
                uploadingState = self.nextStateToSync(after: uploadingState)
                innerLimit = recordLimit - recordsArray.count
            }
        }
        
        return recordsArray
    }
    
    public func didUpload(savedRecords: [CKRecord]) {
        
        guard realmProvider != nil else { return }
        
        executeOnMainQueue {
            
            self.realmProvider.persistenceRealm.beginWriteTransaction()
            for record in savedRecords {
                
                if let syncedEntity = SyncedEntity.object(in: realmProvider.persistenceRealm, forPrimaryKey: record.recordID.recordName) {
                    
                    syncedEntity.state = SyncedEntityState.synced.rawValue
                    syncedEntity.changedKeys = nil
                    self.save(record: record, for: syncedEntity)
                }
                
            }
            try? self.realmProvider.persistenceRealm.commitWriteTransaction()
        }
    }
    
    public func recordIDsMarkedForDeletion(limit: Int) -> [CKRecord.ID] {
        
        guard realmProvider != nil else { return [] }
        
        var recordIDs = [CKRecord.ID]()
        executeOnMainQueue {
            
            let predicate = NSPredicate(format: "state == %ld", SyncedEntityState.deleted.rawValue)
            let deletedEntities = SyncedEntity.objects(in: realmProvider.persistenceRealm, with: predicate)
            
            for object in deletedEntities {
                if recordIDs.count > limit {
                    break
                }
                
                let syncedEntity = object as! SyncedEntity
                recordIDs.append(CKRecord.ID(recordName: syncedEntity.identifier, zoneID: zoneID))
            }
        }
        
        return recordIDs
    }
    
    public func didDelete(recordIDs deletedRecordIDs: [CKRecord.ID]) {
        
        guard realmProvider != nil else { return }
        
        executeOnMainQueue {
            
            self.realmProvider.persistenceRealm.beginWriteTransaction()
            for recordID in deletedRecordIDs {
                
                if let syncedEntity = SyncedEntity.object(in: realmProvider.persistenceRealm, forPrimaryKey: recordID.recordName) {
                    self.realmProvider.persistenceRealm.delete(syncedEntity)
                }
            }
            try? self.realmProvider.persistenceRealm.commitWriteTransaction()
        }
    }
    
    public func hasRecordID(_ recordID: CKRecord.ID) -> Bool {
        
        guard realmProvider != nil else { return false }
        
        var hasRecord = false
        executeOnMainQueue {
            let syncedEntity = SyncedEntity.object(in: realmProvider.persistenceRealm, forPrimaryKey: recordID.recordName)
            hasRecord = syncedEntity != nil
        }
        return hasRecord
    }
    
    public func didFinishImport(with error: Error?) {
    
        guard realmProvider != nil else { return }
        
        tempFileManager.clearTempFiles()
        
        executeOnMainQueue {
            updateHasChanges(realm: self.realmProvider.persistenceRealm)
        }
    }
    
    public func record(for object: AnyObject) -> CKRecord? {
        
        guard realmProvider != nil,
            let realmObject = object as? RLMObject else {
            return nil
        }
        
        var record: CKRecord?
        
        executeOnMainQueue {
            if let syncedEntity = syncedEntity(for: realmObject, realm: self.realmProvider.persistenceRealm) {
                var parent: SyncedEntity?
                record = recordToUpload(syncedEntity: syncedEntity, realmProvider: self.realmProvider, parentSyncedEntity: &parent)
            }
        }
        
        return record
    }
    
    public func share(for object: AnyObject) -> CKShare? {
        
        guard realmProvider != nil,
            let realmObject = object as? RLMObject else {
            return nil
        }
        
        var share: CKShare?
        
        executeOnMainQueue {
            if let syncedEntity = syncedEntity(for: realmObject, realm: self.realmProvider.persistenceRealm) {
                share = getShare(for: syncedEntity)
            }
        }
        
        return share
    }
    
    public func save(share: CKShare, for object: AnyObject) {
    
        guard realmProvider != nil,
            let realmObject = object as? RLMObject else {
            return
        }
        
        executeOnMainQueue {
            if let syncedEntity = syncedEntity(for: realmObject, realm: self.realmProvider.persistenceRealm) {
                
                self.realmProvider.persistenceRealm.beginWriteTransaction()
                self.save(share: share, forSyncedEntity: syncedEntity, realmProvider: self.realmProvider)
                try? self.realmProvider.persistenceRealm.commitWriteTransaction()
            }
        }
    }
    
    public func deleteShare(for object: AnyObject) {
        
        guard realmProvider != nil,
            let realmObject = object as? RLMObject else {
            return
        }
        
        executeOnMainQueue {
            if let syncedEntity = syncedEntity(for: realmObject, realm: self.realmProvider.persistenceRealm),
                let shareEntity = syncedEntity.share {
                
                self.realmProvider.persistenceRealm.beginWriteTransaction()
                syncedEntity.share = nil
                if let record = shareEntity.record {
                    self.realmProvider.persistenceRealm.delete(record)
                }
                self.realmProvider.persistenceRealm.delete(shareEntity)
                try? self.realmProvider.persistenceRealm.commitWriteTransaction()
            }
        }
    }
    
    public func deleteChangeTracking() {
        
        invalidateRealmAndTokens()
        
        let config = self.persistenceRealmConfiguration
        let realmFileURLs: [URL] = [config.fileURL,
                             config.fileURL?.appendingPathExtension("lock"),
                             config.fileURL?.appendingPathExtension("note"),
                             config.fileURL?.appendingPathExtension("management")
            ].compactMap { $0 }
        
        for url in realmFileURLs {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Error deleting file at \(url): \(error)")
            }
        }
    }
    
    public var recordZoneID: CKRecordZone.ID {
        return zoneID
    }
    
    public var serverChangeToken: CKServerChangeToken? {
    
        guard realmProvider != nil else { return nil }
        
        var token: CKServerChangeToken?
        executeOnMainQueue {
            let serverToken = ServerToken.allObjects(in: realmProvider.persistenceRealm).firstObject() as? ServerToken
            if let tokenData = serverToken?.token {
                token = NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
            }
        }
        return token
    }
    
    public func saveToken(_ token: CKServerChangeToken?) {
    
        guard realmProvider != nil else { return }
        
        executeOnMainQueue {
            var serverToken: ServerToken! = ServerToken.allObjects(in: realmProvider.persistenceRealm).firstObject() as? ServerToken
            
            self.realmProvider.persistenceRealm.beginWriteTransaction()
            
            if serverToken == nil {
                serverToken = ServerToken()
                self.realmProvider.persistenceRealm.add(serverToken)
            }
            
            if let token = token {
                serverToken.token = NSKeyedArchiver.archivedData(withRootObject: token)
            } else {
                serverToken.token = nil
            }
            
            try? self.realmProvider.persistenceRealm.commitWriteTransaction()
        }
    }
    
    public func recordsToUpdateParentRelationshipsForRoot(_ object: AnyObject) -> [CKRecord] {
        guard realmProvider != nil,
            let realmObject = object as? RLMObject else {
            return []
        }
        
        var records: [CKRecord]?
        executeOnMainQueue {
            if let syncedEntity = syncedEntity(for: realmObject, realm: self.realmProvider.persistenceRealm) {
                records = self.childrenRecords(for: syncedEntity)
            }
        }
        
        return records ?? []
    }
}
