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

/**
 *  An object implementing `QSCoreDataAdapterDelegate` is responsible for saving the target managed object context at the request of the `QSCoreDataAdapter` in order to persist any downloaded changes.
 */
@objc public protocol CoreDataAdapterDelegate {
    /**
     *  Asks the delegate to save the target managed object context before attempting to merge downloaded changes.
     *
     *  @param coreDataAdapter The `QSCoreDataAdapter` requesting the delegate to save.
     *  @param completion    Block to be called once the managed object context has been saved.
     */
    func coreDataAdapter(_ adapter: CoreDataAdapter, requestsContextSaveWithCompletion completion: (Error?)->())
    /**
     *  Tells the delegate to merge downloaded changes into the managed object context. First, the `importContext` must be saved by using `performBlock`. Then, the target managed object context must be saved to persist those changes and the completion block must be called to finalize the synchronization process.
     *
     *  @param coreDataAdapter The `QSCoreDataAdapter` that is providing the changes.
     *  @param importContext `NSManagedObjectContext` containing all downloaded changes. This context has the target context as its parent context.
     *  @param completion    Block to be called once contexts have been saved.
     */
    func coreDataAdapter(_ adapter: CoreDataAdapter, didImportChanges importContext: NSManagedObjectContext, completion: (Error?)->())
}

@objc public protocol CoreDataAdapterConflictResolutionDelegate {
    /**
     *  Asks the delegate to resolve conflicts for a managed object. The delegate is expected to examine the change dictionary and optionally apply any of those changes to the managed object.
     *
     *  @param coreDataAdapter    The `QSCoreDataAdapter` that is providing the changes.
     *  @param changeDictionary Dictionary containing keys and values with changes for the managed object. Values could be [NSNull null] to represent a nil value.
     *  @param object           The `NSManagedObject` that has changed on iCloud.
     */
    func coreDataAdapter(_ adapter: CoreDataAdapter, gotChanges changeDictionary: [String: Any], for object: NSManagedObject)
}

@objc public class CoreDataAdapter: NSObject {
    /**
     *  The `NSManagedObjectModel` used by the change manager to keep track of changes.
     *
     *  @return The model.
     */
    @objc public class var persistenceModel: NSManagedObjectModel {
        let modelURL = Bundle(for: CoreDataAdapter.self).url(forResource: "QSCloudKitSyncModel", withExtension: "momd")
        return NSManagedObjectModel(contentsOf: modelURL!)!
    }
    
    /**
     *  The target context that will be tracked. (read-only)
     */
    @objc public let targetContext: NSManagedObjectContext
    
    @objc public let delegate: CoreDataAdapterDelegate
    @objc public var conflictDelegate: CoreDataAdapterConflictResolutionDelegate?
    @objc public let recordZoneID: CKRecordZone.ID
    @objc public let stack: CoreDataStack
    @objc public var mergePolicy: MergePolicy = .server
    @objc public var forceDataTypeInsteadOfAsset = false
    
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
        performInitialSetupIfNeeded()
    }
    
    // MARK: - Private
    
    struct RelationshipTarget {
        let originObjectID: String?
        let entityType: String?
    }
    
    class QueryData {
        let identifier: String
        let record: CKRecord?
        let entityType: String
        let changedKeys: [String]
        let state: SyncedEntityState
        var targetRelationshipsDictionary: [String: RelationshipTarget]?
        var toSaveRelationshipNames: [String]?
        
        init(identifier: String, record: CKRecord?, entityType: String, changedKeys: [String], state: SyncedEntityState, targetRelationshipsDictionary: [String: RelationshipTarget]? = nil, toSaveRelationshipNames: [String]? = nil) {
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
    
    var privateContext: NSManagedObjectContext!
    var targetImportContext: NSManagedObjectContext!
    public var hasChanges = false
    var isMergingImportedChanges = false
    var entityPrimaryKeys = [String: String]()
    lazy var tempFileManager: TempFileManager = {
        TempFileManager(identifier: "\(self.recordZoneID.ownerName).\(self.recordZoneID.zoneName)")
    }()
    var childrenRelationships = [String: [ChildRelationship]]()
    public static let timestampKey = "QSCloudKitTimestampKey"
    
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
                    entityPrimaryKeys[entityName] = primaryKeyClass.primaryKey()
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
                                                                            propertiesToFetch: [primaryKey]) as? [[String: String]]
                
                let identifiers = objectIDs?.compactMap({
                    $0[primaryKey]
                })
                self.privateContext?.performAndWait {
                    identifiers?.forEach {
                        self.createSyncedEntity(identifier: $0, entityName: entityName)
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
