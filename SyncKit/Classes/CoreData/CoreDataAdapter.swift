//
//  CoreDataAdapter.swift
//  SyncKit
//
//  Created by Manuel Entrena on 02/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

/// An object implementing `CoreDataAdapterDelegate` is responsible for saving the target managed object context at the request of the `QSCoreDataAdapter` in order to persist any downloaded changes.
@objc public protocol CoreDataAdapterDelegate {

    /// Asks the delegate to save the target managed object context before attempting to merge downloaded changes.
    /// - Parameters:
    ///   - adapter: The `CoreDataAdapter` requesting the delegate to save.
    ///   - completion: Block to be called once the managed object context has been saved.
    func coreDataAdapter(_ adapter: CoreDataAdapter, requestsContextSaveWithCompletion completion: (Error?)->())
    
    /// Tells the delegate to merge downloaded changes into the managed object context. First, the `importContext` must be saved by using `performBlock`. Then, the target managed object context must be saved to persist those changes and the completion block must be called to finalize the synchronization process.
    /// - Parameters:
    ///   - adapter: The `CoreDataAdapter` that is providing the changes.
    ///   - importContext: `NSManagedObjectContext` containing all downloaded changes. This context has the target context as its parent context.
    ///   - completion: Block to be called once contexts have been saved.
    func coreDataAdapter(_ adapter: CoreDataAdapter, didImportChanges importContext: NSManagedObjectContext, completion: (Error?)->())
}


/// An implementation of this protocol can be provided for custom conflict resolution.
@objc public protocol CoreDataAdapterConflictResolutionDelegate {

    /// Asks the delegate to resolve conflicts for a managed object. The delegate is expected to examine the change dictionary and optionally apply any of those changes to the managed object.
    /// - Parameters:
    ///   - adapter: The `CoreDataAdapter` that is providing the changes.
    ///   - changeDictionary: Dictionary containing keys and values with changes for the managed object. Values could be [NSNull null] to represent a nil value.
    ///   - object: The `NSManagedObject` that has changed on iCloud.
    func coreDataAdapter(_ adapter: CoreDataAdapter, gotChanges changeDictionary: [String: Any], for object: NSManagedObject)
}


/// An implementation of this protocol can be provided for custom `CKRecord` generation.
@objc public protocol CoreDataAdapterRecordProcessing: AnyObject {
    
    /// Called by the adapter before copying a property from the Core Data object to the CloudKit record to upload to CloudKit. The method can then apply custom logic to encode the property in the record.
    /// - Parameters:
    ///   - propertyName: The name of the property that is being processed
    ///   - object: The `NSManagedObject` that is going to have its record uploaded.
    ///   - record: The `CKRecord` that is being configured before being sent to CloudKit.
    func shouldProcessPropertyBeforeUpload(propertyName: String, object: NSManagedObject, record: CKRecord) -> Bool
    
    /// Called by the adapter before copying a property from the CloudKit record that was just downloaded to the Core Data object. The method can apply custom logic to save the property from the record to the object. An object implementing this method *should not* change the record itself.
    /// - Parameters:
    ///   - propertyName: The name of the property that is being processed
    ///   - object: The `NSManagedObject` that corresponds to the downloaded record.
    ///   - record:  The `CKRecord` that was downloaded from CloudKit.
    func shouldProcessPropertyInDownload(propertyName: String, object: NSManagedObject, record: CKRecord) -> Bool
}


/// Implementation of `ModelAdapter` for Core Data models.
@objc public class CoreDataAdapter: NSObject, ModelAdapter {

    /// The `NSManagedObjectModel` used by the model adapter to keep track of changes, internally.
    @objc class var persistenceModel: NSManagedObjectModel {
        #if SPM
        let modelURL = Bundle.module.url(forResource: "QSCloudKitSyncModel", withExtension: "momd")
        #else
        let modelURL = Bundle(for: CoreDataAdapter.self).url(forResource: "QSCloudKitSyncModel", withExtension: "momd")
        #endif
        return NSManagedObjectModel(contentsOf: modelURL!)!
    }
    
    /// The target `NSManagedObjectContext` that will be tracked. (read-only)
    @objc public let targetContext: NSManagedObjectContext
    
    
    @objc public let delegate: CoreDataAdapterDelegate
    @objc public weak var recordProcessingDelegate: CoreDataAdapterRecordProcessing?
    @objc public var conflictDelegate: CoreDataAdapterConflictResolutionDelegate?
    
    /// Record Zone that is kept in sync with this adapter's `NSManagedObjectContext`.
    @objc public let recordZoneID: CKRecordZone.ID
    
    /// Merge policy in case of conflicts. Default value is `server`.
    @objc public var mergePolicy: MergePolicy = .server
    
    /// By default objects with `Data` values will be uploaded as a `CKRecord` with a `CKAsset` field. Set this property to `true` to force using `Data` in the record instead.
    @objc public var forceDataTypeInsteadOfAsset = false
    
    
    /// Whether the target context has made any changes that have not been synced to CloudKit yet.
    public var hasChanges = false
    
    
    /// Records generated by this adapter will use this key to set a change timestamp.
    public static let timestampKey = "QSCloudKitTimestampKey"
    
    /// Initialize a new `CoreDataAdapter`.
    /// - Parameters:
    ///   - persistenceStack: `CoreDataStack` for internal state.
    ///   - targetContext: `NSManagedObjectContext` to keep in sync with CloudKit.
    ///   - recordZoneID: `CKRecordZone.ID` of the record zone that will be used on CloudKit.
    ///   - delegate: `CoreDataAdapterDelegate` to trigger saves in the target context.
    @objc public init(persistenceStack: CoreDataStack, targetContext: NSManagedObjectContext, recordZoneID: CKRecordZone.ID, delegate: CoreDataAdapterDelegate) {
        self.stack = persistenceStack
        self.targetContext = targetContext
        self.recordZoneID = recordZoneID
        self.delegate = delegate
        self.privateContext = persistenceStack.managedObjectContext
        super.init()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(targetContextWillSave(notification:)),
                                               name: .NSManagedObjectContextWillSave,
                                               object: targetContext)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(targetContextDidSave(notification:)),
                                               name: .NSManagedObjectContextDidSave,
                                               object: targetContext)
        setupPrimaryKeysLookup()
        setupChildrenRelationshipsLookup()
        setupEncryptedFields()
        performInitialSetupIfNeeded()
    }
    
    // MARK: - Private
    
    struct RelationshipTarget {
        let originObjectID: PrimaryKeyValue?
        let entityType: String?
    }
    
    class QueryData {
        let identifier: PrimaryKeyValue
        let record: CKRecord?
        let entityType: String
        let changedKeys: [String]
        let state: SyncedEntityState
        var targetRelationshipsDictionary: [String: RelationshipTarget]?
        var toSaveRelationshipNames: [String]?
        
        init(identifier: PrimaryKeyValue, record: CKRecord?, entityType: String, changedKeys: [String], state: SyncedEntityState, targetRelationshipsDictionary: [String: RelationshipTarget]? = nil, toSaveRelationshipNames: [String]? = nil) {
            self.identifier = identifier
            self.record = record
            self.entityType = entityType
            self.changedKeys = changedKeys
            self.state = state
            self.targetRelationshipsDictionary = targetRelationshipsDictionary
            self.toSaveRelationshipNames = toSaveRelationshipNames
        }
    }
    
    struct ChildRelationship {
        let parentEntityName: String
        let childEntityName: String
        let childParentKey: String
    }
    
    struct PropertyDescription {
        let name: String
        let type: NSAttributeType
    }
    
    var privateContext: NSManagedObjectContext!
    var targetImportContext: NSManagedObjectContext!
    let stack: CoreDataStack
    var isMergingImportedChanges = false
    var entityPrimaryKeys = [String: PropertyDescription]()
    var entityEncryptedFields = [String: Set<String>]()
    lazy var tempFileManager: TempFileManager = {
        TempFileManager(identifier: "\(self.recordZoneID.ownerName).\(self.recordZoneID.zoneName)")
    }()
    var childrenRelationships = [String: [ChildRelationship]]()
}

// MARK: - Setup
extension CoreDataAdapter {
    private func setupPrimaryKeysLookup() {
        
        targetContext.performAndWait {
            guard let entities = self.targetContext.persistentStoreCoordinator?.managedObjectModel.entities else { return }
            for entityDescription in entities {
                let entityClass: AnyClass? = NSClassFromString(entityDescription.managedObjectClassName)
                if let primaryKeyClass = entityClass as? PrimaryKey.Type,
                    let entityName = entityDescription.name {
                    let key = primaryKeyClass.primaryKey()
                    entityPrimaryKeys[entityName] = PropertyDescription(name: key, type: entityDescription.attributesByName[key]!.attributeType)
                } else {
                    assert(false, "PrimaryKey protocol not implemented for class: \(String(describing: entityClass))")
                }
            }
        }
    }
    
    private func setupChildrenRelationshipsLookup() {
        targetContext.performAndWait {
            guard let entities = self.targetContext.persistentStoreCoordinator?.managedObjectModel.entities else { return }
            for entityDescription in entities {
                let entityClass: AnyClass? = NSClassFromString(entityDescription.managedObjectClassName)
                if let parentKeyClass = entityClass as? ParentKey.Type {
                    let parentKey = parentKeyClass.parentKey()
                    guard let relationshipDescription = entityDescription.relationshipsByName[parentKey],
                    let parentEntity = relationshipDescription.destinationEntity,
                    let parentName = parentEntity.name,
                    let childName = entityDescription.name else { continue }
                    let relationship = ChildRelationship(parentEntityName: parentName, childEntityName: childName, childParentKey: parentKey)
                    if childrenRelationships[parentName] == nil {
                        childrenRelationships[parentName] = [ChildRelationship]()
                    }
                    childrenRelationships[parentName]?.append(relationship)
                }
            }
        }
    }
    
    private func setupEncryptedFields() {
        if #available(iOS 15, OSX 12, watchOS 8.0, *) {
            targetContext.performAndWait {
                guard let entities = self.targetContext.persistentStoreCoordinator?.managedObjectModel.entities else { return }
                for entityDescription in entities {
                    let entityClass: AnyClass? = NSClassFromString(entityDescription.managedObjectClassName)
                    if let primaryKeyClass = entityClass as? EncryptedObject.Type,
                       let entityName = entityDescription.name {
                        let fields = primaryKeyClass.encryptedFields()
                        if !fields.isEmpty {
                            entityEncryptedFields[entityName] = Set(fields)
                        }
                    }
                }
            }
        }
    }
    
    private func performInitialSetupIfNeeded() {
        privateContext.performAndWait {
            var count = 0
            if let fetchedObjects = try? self.privateContext.executeFetchRequest(entityName: "QSSyncedEntity", fetchLimit: 1, resultType: .countResultType),
                let entityCount = fetchedObjects.first as? Int {
                count = entityCount
            }
            
            if count == 0 {
                self.performInitialSetup()
            } else {
                self.updateHasChanges()
                if hasChanges {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .ModelAdapterHasChangesNotification, object: self)
                    }
                }
            }
        }
    }
    
    private func performInitialSetup() {
        targetContext.perform {
            guard let entities = self.targetContext.persistentStoreCoordinator?.managedObjectModel.entities else { return }
            for entityDescription in entities {
                guard let entityName = entityDescription.name else { continue }
                let primaryKey = self.identifierFieldName(forEntity: entityName)
                let objectIDs = try? self.targetContext.executeFetchRequest(entityName: entityName,
                                                                            resultType: .dictionaryResultType,
                                                                            propertiesToFetch: [primaryKey]) as? [[String: Any]]
                
                let identifiers = objectIDs?.compactMap({ keyDict -> PrimaryKeyValue? in
                    guard let id = keyDict[primaryKey] else { return nil }
                    return PrimaryKeyValue(value: id)
                })
                self.privateContext?.performAndWait {
                    identifiers?.forEach {
                        self.createSyncedEntity(identifier: $0.description, entityName: entityName)
                    }
                    self.savePrivateContext()
                }
            }
            
            self.privateContext?.perform {
                self.updateHasChanges()
                if self.hasChanges {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .ModelAdapterHasChangesNotification,
                                                        object: self)
                    }
                }
            }
        }
    }
    
    func updateHasChanges() {
        if let fetchedObjects = try? self.privateContext.executeFetchRequest(entityName: "QSSyncedEntity",
                                                                     predicate: NSPredicate(format: "state < %d", SyncedEntityState.synced.rawValue),
                                                                     fetchLimit: 1,
                                                                     resultType: .countResultType),
            let count = fetchedObjects.first as? Int {
            hasChanges = count > 0
        }
    }
}
