//
//  QSCoreDataChangeManager.m
//  Pods
//
//  Created by Manuel Entrena on 10/07/2016.
//
//

#import "QSCoreDataChangeManager.h"
#import "QSPrimaryKey.h"
#import "QSSyncedEntityState.h"
#import "QSSyncedEntity+CoreDataClass.h"
#import "QSRecord+CoreDataClass.h"
#import "QSPendingRelationship+CoreDataClass.h"
#import "NSManagedObjectContext+QSFetch.h"
#import "QSCloudKitSynchronizer.h"
#import <CloudKit/CloudKit.h>

#define callBlockIfNotNil(block, ...) if (block){block(__VA_ARGS__);}
static NSString * const QSCloudKitTimestampKey = @"QSCloudKitTimestampKey";

@interface QSCoreDataChangeManager ()

@property (nonatomic, readwrite, strong) QSCoreDataStack *stack;
@property (nonatomic, strong) NSManagedObjectContext *privateContext;
@property (nonatomic, strong) NSManagedObjectContext *targetImportContext;
@property (nonatomic, assign) BOOL hasChanges;
@property (nonatomic, assign, getter=isMergingImportedChanges) BOOL mergingImportedChanges;
@property (nonatomic, strong, readwrite) NSManagedObjectContext *targetContext;
@property (nonatomic, readwrite) id<QSCoreDataChangeManagerDelegate> delegate;
@property (nonatomic, readwrite, strong) CKRecordZoneID *zoneID;
@property (nonatomic, strong) NSDictionary *entityPrimaryKeys;

@end

@implementation QSCoreDataChangeManager

+ (NSManagedObjectModel *)persistenceModel
{
    NSURL *modelURL = [[NSBundle bundleForClass:[QSCoreDataChangeManager class]] URLForResource:@"QSCloudKitSyncModel" withExtension:@"momd"];
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
}

- (instancetype)initWithPersistenceStack:(QSCoreDataStack *)stack targetContext:(NSManagedObjectContext *)targetContext recordZoneID:(CKRecordZoneID *)zoneID delegate:(id<QSCoreDataChangeManagerDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.stack = stack;
        self.targetContext = targetContext;
        self.delegate = delegate;
        self.zoneID = zoneID;
        
        self.privateContext = stack.managedObjectContext;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(targetContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:self.targetContext];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(targetContextWillSave:) name:NSManagedObjectContextWillSaveNotification object:self.targetContext];
        
        [self setupPrimaryKeysLookup];
        
        [self performInitialSetupIfNeeded];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextWillSaveNotification object:nil];
}

- (void)savePrivateContext
{
    NSError *error = nil;
    [self.privateContext save:&error];
}

#pragma mark - initial setup

- (void)performInitialSetupIfNeeded
{
    [self.privateContext performBlock:^{
        NSError *error = nil;
        NSArray *fetchedObjects = [self.privateContext executeFetchRequestWithEntityName:@"QSSyncedEntity" predicate:nil fetchLimit:1 resultType:NSCountResultType error:&error];
        NSInteger count = [[fetchedObjects firstObject] integerValue];
        
        if (count == 0) {
            [self performInitialSetup];
        } else {
            [self updateHasChanges];
            if (self.hasChanges) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:QSChangeManagerHasChangesNotification object:self];
                });
            }
        }
    }];
}

- (void)performInitialSetup
{
    [self.targetContext performBlock:^{
        NSArray *entities = self.targetContext.persistentStoreCoordinator.managedObjectModel.entities;
        
        for (NSEntityDescription *entityDescription in entities) {
            NSError *error = nil;
            NSString *primaryKey = [self identifierFieldNameForEntityOfType:entityDescription.managedObjectClassName];
            NSArray *objectIDs;
            if (primaryKey) {
                //Get object identifiers using primary key
                objectIDs = [self.targetContext executeFetchRequestWithEntityName:entityDescription.name predicate:nil fetchLimit:0 resultType:NSDictionaryResultType propertiesToFetch:@[primaryKey] error:&error];
                objectIDs = [objectIDs valueForKey:primaryKey];
            } else {
                //Get objectIDs
                objectIDs = [self.targetContext executeFetchRequestWithEntityName:entityDescription.name predicate:nil fetchLimit:0 resultType:NSManagedObjectIDResultType error:&error];
                NSMutableArray *objectIDStrings = [NSMutableArray array];
                [objectIDs enumerateObjectsUsingBlock:^(NSManagedObjectID *  _Nonnull objectID, NSUInteger idx, BOOL * _Nonnull stop) {
                    [objectIDStrings addObject:[objectID.URIRepresentation absoluteString]];
                }];
                objectIDs = [objectIDStrings copy];
            }
            
            //Create records
            [self.privateContext performBlockAndWait:^{
                for (NSString *objectIdentifier in objectIDs) {
                    [self createSyncedEntityWithIdentifier:objectIdentifier entityName:entityDescription.name];
                }
                
                [self savePrivateContext];
            }];
        }
        
        [self.privateContext performBlock:^{
            [self updateHasChanges];
            if (self.hasChanges) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:QSChangeManagerHasChangesNotification object:self];
                });
            }
        }];
    }];
}

- (void)setupPrimaryKeysLookup
{
    [self.targetContext performBlockAndWait:^{
        NSArray *entities = self.targetContext.persistentStoreCoordinator.managedObjectModel.entities;
        NSMutableDictionary *primaryKeys = [NSMutableDictionary dictionary];
        for (NSEntityDescription *entityDescription in entities) {
            Class entityClass = NSClassFromString(entityDescription.name);
            if ([entityClass conformsToProtocol:@protocol(QSPrimaryKey)]) {
                primaryKeys[entityDescription.name] = [entityClass primaryKey];
            }
        }
        self.entityPrimaryKeys = [primaryKeys copy];
    }];
}

- (void)updateHasChanges
{
    NSError *error = nil;
    NSArray *fetchedObjects = [self.privateContext executeFetchRequestWithEntityName:@"QSSyncedEntity"
                                                                           predicate:[NSPredicate predicateWithFormat:@"state < %d", QSSyncedEntityStateSynced]
                                                                          fetchLimit:1
                                                                          resultType:NSCountResultType
                                                                               error:&error];
    
    NSInteger count = [[fetchedObjects firstObject] integerValue];
    self.hasChanges = count > 0;
}

#pragma mark - Object identification

- (BOOL)useUniqueIdentifierForEntityWithType:(NSString *)entityType
{
    return self.entityPrimaryKeys[entityType] != nil;
}

- (NSString *)identifierFieldNameForEntityOfType:(NSString *)entityType
{
    return self.entityPrimaryKeys[entityType];
}

- (NSString *)uniqueIdentifierForObject:(NSManagedObject *)object
{
    NSString *key = self.entityPrimaryKeys[object.entity.name];
    if (key) {
        return [object valueForKey:key];
    } else {
        return [object.objectID.URIRepresentation absoluteString];
    }
}

- (NSString *)uniqueIdentifierForObjectFromRecord:(CKRecord *)record
{
    NSString *entityType = record.recordType;
    if ([self useUniqueIdentifierForEntityWithType:entityType]) {
        return [record.recordID.recordName substringFromIndex:entityType.length + 1];
    }
    return nil;
}

#pragma mark - Persistence management

#pragma mark Entities

- (void)createSyncedEntityWithIdentifier:(NSString *)identifier entityName:(NSString *)entityName
{
    QSSyncedEntity *syncedEntity = [[QSSyncedEntity alloc] initWithEntity:[NSEntityDescription entityForName:@"QSSyncedEntity" inManagedObjectContext:self.privateContext] insertIntoManagedObjectContext:self.privateContext];
    
    syncedEntity.entityType = entityName;
    syncedEntity.state = @(QSSyncedEntityStateNew);
    syncedEntity.updated = [NSDate date];
    syncedEntity.originObjectID = identifier;
    if ([self useUniqueIdentifierForEntityWithType:entityName]) {
        syncedEntity.identifier = [NSString stringWithFormat:@"%@.%@", entityName, identifier];
    } else {
        NSUUID *uuid = [NSUUID UUID];
        syncedEntity.identifier = [NSString stringWithFormat:@"%@.%@", entityName, [uuid UUIDString]];
    }
}

- (NSArray *)entitiesWithState:(QSSyncedEntityState)state
{
    NSError *error = nil;
    return [self.privateContext executeFetchRequestWithEntityName:@"QSSyncedEntity"
                                                        predicate:[NSPredicate predicateWithFormat:@"state == %lud", state]
                                                            error:&error];
}

- (QSSyncedEntity *)syncedEntityWithIdentifier:(NSString *)identifier
{
    NSError *error = nil;
    NSArray *fetchedObjects = [self.privateContext executeFetchRequestWithEntityName:@"QSSyncedEntity"
                                                                           predicate:[NSPredicate predicateWithFormat:@"identifier == %@", identifier]
                                                                          fetchLimit:1
                                                                               error:&error];
    return [fetchedObjects firstObject];
}

- (NSDictionary *)originObjectIdentifierForEntityWithIdentifier:(NSString *)identifier
{
    NSError *error = nil;
    
    NSArray *results = [self.privateContext executeFetchRequestWithEntityName:@"QSSyncedEntity"
                                                                    predicate:[NSPredicate predicateWithFormat:@"identifier == %@", identifier]
                                                                   fetchLimit:1
                                                                   resultType:NSDictionaryResultType
                                                            propertiesToFetch:@[@"originObjectID", @"entityType"]
                                                                        error:&error];

    return [results firstObject];
}

- (QSSyncedEntity *)syncedEntityWithOriginObjectIdentifier:(NSString *)objectIdentifier
{
    NSError *error = nil;
    NSArray *fetchedObjects = [self.privateContext executeFetchRequestWithEntityName:@"QSSyncedEntity"
                                                                           predicate:[NSPredicate predicateWithFormat:@"originObjectID == %@", objectIdentifier]
                                                                               error:&error];
    return [fetchedObjects firstObject];
}

- (NSDictionary *)referencedSyncedEntitiesByReferenceNameForManagedObject:(NSManagedObject *)object
{
    __block NSDictionary *objectIDsByRelationshipName = nil;
    [self.targetImportContext performBlockAndWait:^{
        objectIDsByRelationshipName = [self referencedObjectIdentifiersByRelationshipNameForManagedObject:object];
    }];
    
    NSMutableDictionary *entitiesByName = [NSMutableDictionary dictionary];
    [objectIDsByRelationshipName enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull relationshipName, NSString *  _Nonnull objectIdentifier, BOOL * _Nonnull stop) {
        QSSyncedEntity *entity = [self syncedEntityWithOriginObjectIdentifier:objectIdentifier];
        if (entity) {
            entitiesByName[relationshipName] = entity;
        }
    }];
    return [entitiesByName copy];
}

- (void)deleteSyncedEntity:(QSSyncedEntity *)syncedEntity
{
    NSString *originObjectID = syncedEntity.originObjectID;
    if ([syncedEntity.state integerValue] != QSSyncedEntityStateDeleted && originObjectID) {
        NSString *entityName = syncedEntity.entityType;
        [self.targetImportContext performBlockAndWait:^{
            NSManagedObject *managedObject = [self managedObjectWithEntityName:entityName identifier:originObjectID];
            
            if (managedObject) {
                [self.targetImportContext deleteObject:managedObject];
            }
        }];
    }
    
    [self.privateContext deleteObject:syncedEntity];
}

- (void)deleteInsertedButUnmergedEntities
{
    NSArray *pendingEntities = [self entitiesWithState:QSSyncedEntityStateInserted];
    for (QSSyncedEntity *pending in [pendingEntities copy]) {
        [self.privateContext deleteObject:pending];
    }
}

- (void)updateInsertedEntitiesAndSave
{
    NSArray *pendingEntities = [self entitiesWithState:QSSyncedEntityStateInserted];
    for (QSSyncedEntity *pending in [pendingEntities copy]) {
        pending.state = @(QSSyncedEntityStateSynced);
    }
    [self savePrivateContext];
}

#pragma mark Synced Entities and Records

- (void)saveRecord:(CKRecord *)record forSyncedEntity:(QSSyncedEntity *)entity
{
    QSRecord *qsRecord = entity.record;
    if (!qsRecord) {
        qsRecord = [[QSRecord alloc] initWithEntity:[NSEntityDescription entityForName:@"QSRecord" inManagedObjectContext:self.privateContext] insertIntoManagedObjectContext:self.privateContext];
        entity.record = qsRecord;
    }
    qsRecord.encodedRecord = [self encodedRecord:record];
}

- (NSData *)encodedRecord:(CKRecord *)record
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [record encodeSystemFieldsWithCoder:archiver];
    [archiver finishEncoding];
    return [data copy];
}

- (CKRecord *)recordForSyncedEntity:(QSSyncedEntity *)entity
{
    CKRecord *record = nil;
    if (entity.record) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:entity.record.encodedRecord];
        record = [[CKRecord alloc] initWithCoder:unarchiver];
        [unarchiver finishDecoding];
    }
    return record;
}

- (QSSyncedEntity *)createSyncedEntityForRecord:(CKRecord *)record
{
    QSSyncedEntity *syncedEntity = [[QSSyncedEntity alloc] initWithEntity:[NSEntityDescription entityForName:@"QSSyncedEntity" inManagedObjectContext:self.privateContext] insertIntoManagedObjectContext:self.privateContext];
    syncedEntity.identifier = record.recordID.recordName;
    NSString *entityName = record.recordType;
    syncedEntity.entityType = entityName;
    syncedEntity.updated = [NSDate date];
    syncedEntity.state = @(QSSyncedEntityStateInserted);
    
    //Insert managedObject
    __block NSString *objectID = nil;
    [self.targetImportContext performBlockAndWait:^{
        NSManagedObject *object = [self insertManagedObjectWithEntityName:entityName];
        objectID = [self uniqueIdentifierForObjectFromRecord:record];
        if (!objectID) {
            objectID = [object.objectID.URIRepresentation absoluteString];
        }
    }];
    
    syncedEntity.originObjectID = objectID;
    
    return syncedEntity;
}

- (CKRecord *)recordToUploadForSyncedEntity:(QSSyncedEntity *)entity
{
    CKRecord *record = [self recordForSyncedEntity:entity];
    if (!record) {
        record = [[CKRecord alloc] initWithRecordType:entity.entityType recordID:[[CKRecordID alloc] initWithRecordName:entity.identifier zoneID:self.zoneID]];
    }
    
    //To assign only attributes that have changed, if state == changed. Assign everything if state == new
    NSArray *changedKeys = [entity.changedKeys componentsSeparatedByString:@","];
    
    __block NSManagedObject *originalObject;
    __block NSEntityDescription *entityDescription;
    NSString *objectID = entity.originObjectID;
    QSSyncedEntityState entityState = [entity.state integerValue];
    NSString *entityType = entity.entityType;
    [self.targetImportContext performBlockAndWait:^{
        originalObject = [self managedObjectWithEntityName:entityType identifier:objectID];
        entityDescription = [NSEntityDescription entityForName:entityType inManagedObjectContext:self.targetImportContext];
        
        //Add attributes
        [[entityDescription attributesByName] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull attributeName, NSAttributeDescription * _Nonnull attributeDescription, BOOL * _Nonnull stop) {
            if (entityState == QSSyncedEntityStateNew || [changedKeys containsObject:attributeName]) {
                record[attributeName] = [originalObject valueForKey:attributeName];
            }
        }];
    }];
    
    NSDictionary *referencedEntities = [self referencedSyncedEntitiesByReferenceNameForManagedObject:originalObject];
    [referencedEntities enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull relationshipName, QSSyncedEntity  * _Nonnull entity, BOOL * _Nonnull stop) {
        if (entityState == QSSyncedEntityStateNew || [changedKeys containsObject:relationshipName]) {
            CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName:entity.identifier zoneID:self.zoneID];
            CKReference *recordReference = [[CKReference alloc] initWithRecordID:recordID action:CKReferenceActionNone];
            record[relationshipName] = recordReference;
        }
    }];
    
    record[QSCloudKitTimestampKey] = entity.updated;
    
    return record;
}

- (NSArray *)recordsToUploadWithState:(QSSyncedEntityState)state limit:(NSInteger)limit
{
    __block NSArray *recordsArray = nil;
    
    [self.privateContext performBlockAndWait:^{
        NSArray *entities = [self entitiesWithState:state];
        if (entities.count == 0) {
            recordsArray = @[];
        } else {
            NSMutableArray *pending = [NSMutableArray arrayWithArray:entities];
            NSMutableArray *records = [NSMutableArray array];
            NSMutableDictionary *entitiesByID = [NSMutableDictionary dictionary];
            
            while (records.count < limit && pending.count) {
                QSSyncedEntity *entity = [pending lastObject];
                entitiesByID[entity.identifier] = entity;
                [pending removeLastObject];
                
                CKRecord *record = [self recordToUploadForSyncedEntity:entity];
                [records addObject:record];
            }
            
            recordsArray = [records copy];
        }
    }];
    
    return recordsArray;
}

#pragma mark Pending relationships

- (void)deleteAllPendingRelationships
{
    NSError *error = nil;
    NSArray *pendingRelationships = [self.privateContext executeFetchRequestWithEntityName:@"QSPendingRelationship" error:&error];
    for (QSPendingRelationship *pending in [pendingRelationships copy]) {
        [self.privateContext deleteObject:pending];
    }
}

- (NSArray *)entitiesWithPendingRelationships
{
    NSError *error = nil;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"QSSyncedEntity" inManagedObjectContext:self.privateContext];
    [fetchRequest setEntity:entity];
    fetchRequest.resultType = NSManagedObjectResultType;
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"pendingRelationships.@count != 0"];
    fetchRequest.returnsObjectsAsFaults = NO;
    fetchRequest.relationshipKeyPathsForPrefetching = @[@"originIdentifier", @"pendingRelationships"];
    return [self.privateContext executeFetchRequest:fetchRequest error:&error];
}

- (void)saveRelationshipChangesInRecord:(CKRecord *)record forEntity:(QSSyncedEntity *)entity
{
    for (NSString *key in record.allKeys) {
        //Assign attributes directly
        if ([record[key] isKindOfClass:[CKReference class]]) {
            CKReference *reference = record[key];
            QSPendingRelationship *relationship = [NSEntityDescription insertNewObjectForEntityForName:@"QSPendingRelationship" inManagedObjectContext:self.privateContext];
            relationship.relationshipName = key;
            relationship.targetIdentifier = reference.recordID.recordName;
            relationship.forEntity = entity;
        }
    }
}

- (NSDictionary *)pendingRelationshipTargetIdentifiersForEntity:(QSSyncedEntity *)entity
{
    NSMutableDictionary *relationships = [NSMutableDictionary dictionary];
    for (QSPendingRelationship *pendingRelationship in entity.pendingRelationships) {
        NSDictionary *targetObjectInfo = [self originObjectIdentifierForEntityWithIdentifier:pendingRelationship.targetIdentifier];
        if (targetObjectInfo) {
            relationships[pendingRelationship.relationshipName] = targetObjectInfo;
        }
    }
    
    return relationships;
}

- (void)applyPendingRelationships
{
    //Need to save before we can use NSDictionaryResultType, which greatly speeds up this step
    [self savePrivateContext];

    NSArray *entities = [self entitiesWithPendingRelationships];
    
    NSMutableArray *entitiesAndTargetRelationships = [NSMutableArray array];
    for (QSSyncedEntity *entity in entities) {
        [entitiesAndTargetRelationships addObject:@{@"originID": entity.originObjectID,
                                                    @"entityType": entity.entityType,
                                                    @"relationshipsDict": [self pendingRelationshipTargetIdentifiersForEntity:entity],
                                                    @"originState": entity.state,
                                                    @"changedKeys": [entity.changedKeys componentsSeparatedByString:@","] ? : @[]}];
        
        for (QSPendingRelationship *pendingRelationship in [entity.pendingRelationships copy]) {
            [self.privateContext deleteObject:pendingRelationship];
        }
    }
    
    [self.targetImportContext performBlockAndWait:^{
        [self targetApplyPendingRelationships:entitiesAndTargetRelationships];
    }];
}

- (void)targetApplyPendingRelationships:(NSArray *)array
{
    for (NSDictionary *dict in array) {
        NSString *objectID = dict[@"originID"];
        NSString *entityType = dict[@"entityType"];
        NSManagedObject *managedObject = [self managedObjectWithEntityName:entityType identifier:objectID];
        
        NSDictionary *targetRelationships = dict[@"relationshipsDict"];
        NSNumber *state = dict[@"originState"];
        NSArray *changedKeys = dict[@"changedKeys"];
        
        for (NSString *relationshipName in targetRelationships.allKeys) {
            NSDictionary *targetObjectInfo = targetRelationships[relationshipName];
            NSString *targetIdentifier = targetObjectInfo[@"originObjectID"];
            NSString *targetEntityType = targetObjectInfo[@"entityType"];
            if ([state integerValue] > QSSyncedEntityStateChanged //Not changed, not new
                ||
                self.mergePolicy == QSCloudKitSynchronizerMergePolicyServer
                ||
                (self.mergePolicy == QSCloudKitSynchronizerMergePolicyClient &&
                 (![changedKeys containsObject:relationshipName] || ([state integerValue] == QSSyncedEntityStateNew && [managedObject valueForKey:relationshipName] == nil))
                 )
                ) {
                
                NSManagedObject *targetManagedObject = [self managedObjectWithEntityName:targetEntityType identifier:targetIdentifier];
                [managedObject setValue:targetManagedObject forKey:relationshipName];
            } else if (self.mergePolicy == QSCloudKitSynchronizerMergePolicyCustom) {
                NSManagedObject *targetManagedObject = [self managedObjectWithEntityName:targetEntityType identifier:targetIdentifier];
                if ([self.delegate respondsToSelector:@selector(changeManager:gotChanges:forObject:)]) {
                    [self.targetImportContext performBlockAndWait:^{
                        [self.delegate changeManager:self gotChanges:@{relationshipName: targetManagedObject} forObject:managedObject];
                    }];
                }
            }
        }
    }
}

#pragma mark Target context

- (NSManagedObject *)insertManagedObjectWithEntityName:(NSString *)entityName
{
    NSManagedObject *managedObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.targetImportContext];
    NSError *error = nil;
    [self.targetImportContext obtainPermanentIDsForObjects:@[managedObject] error:&error];
    return managedObject;
}

- (NSManagedObject *)managedObjectWithEntityName:(NSString *)entityName identifier:(NSString *)identifier
{
    if ([self useUniqueIdentifierForEntityWithType:entityName]) {
        return [self managedObjectWithEntityName:entityName
                                             key:[self identifierFieldNameForEntityOfType:entityName]
                                      identifier:identifier];
    } else {
        return [self managedObjectForIDURIRepresentationString:identifier];
    }
}

- (NSManagedObject *)managedObjectForIDURIRepresentationString:(NSString *)objectIDURIString
{
    if (!objectIDURIString) {
        return nil;
    }
    
    NSManagedObjectID *originalObjectID = [self.targetImportContext.persistentStoreCoordinator managedObjectIDForURIRepresentation:[NSURL URLWithString:objectIDURIString]];
    if (originalObjectID.temporaryID) {
        return nil;
    }
    
    NSManagedObject *originalObject = [self.targetImportContext objectWithID:originalObjectID];
    return originalObject;
}

- (NSManagedObject *)managedObjectWithEntityName:(NSString *)entityName key:(NSString *)identifierKey identifier:(NSString *)identifier
{
    if (!entityName || !identifierKey || !identifier) {
        return nil;
    }
    
    NSError *error = nil;
    NSArray *results = [self.targetImportContext executeFetchRequestWithEntityName:entityName predicate:[NSPredicate predicateWithFormat:@"%K == %@", identifierKey, identifier] error:&error];
    NSManagedObject *object = [results firstObject];
    
    return object;
}

- (NSDictionary *)referencedObjectIdentifiersByRelationshipNameForManagedObject:(NSManagedObject *)object
{
    NSDictionary *relationships = [object.entity relationshipsByName];
    
    NSMutableDictionary *objectIDs = [NSMutableDictionary dictionary];
    for (NSRelationshipDescription *relationshipDescription in [relationships allValues]) {
        if (relationshipDescription.toMany == NO) {
            NSManagedObject *referencedObject = [object valueForKey:relationshipDescription.name];
            if (referencedObject) {
                NSString *identifier = [self uniqueIdentifierForObject:referencedObject];
                objectIDs[relationshipDescription.name] = identifier;
            }
        }
    }
    
    return [objectIDs copy];
}

- (void)applyAttributeChangesInRecord:(CKRecord *)record toManagedObject:(NSManagedObject *)managedObject withSyncedState:(QSSyncedEntityState)state changedKeys:(NSArray *)entityChangedKeys
{
    if (state == QSSyncedEntityStateChanged || state == QSSyncedEntityStateNew) {
        switch (self.mergePolicy) {
            case QSCloudKitSynchronizerMergePolicyServer:
            {
                for (NSString *key in record.allKeys) {
                    if ([self shouldIgnoreKey:key]) {
                        continue;
                    }
                    if (![record[key] isKindOfClass:[CKReference class]]) {
                        [managedObject setValue:record[key] forKey:key];
                    }
                }
                break;
            }
            case QSCloudKitSynchronizerMergePolicyClient:
            {
                for (NSString *key in record.allKeys) {
                    if ([self shouldIgnoreKey:key]) {
                        continue;
                    }
                    if (![record[key] isKindOfClass:[CKReference class]]) {
                        if (![entityChangedKeys containsObject:key] &&
                            (state != QSSyncedEntityStateNew || [managedObject valueForKey:key] == nil)) {
                            [managedObject setValue:record[key] forKey:key];
                        }
                    }
                }
                break;
            }
            case QSCloudKitSynchronizerMergePolicyCustom:
            {
                NSMutableDictionary *recordChanges = [NSMutableDictionary dictionary];
                [record.allKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (![record[obj] isKindOfClass:[CKReference class]]) {
                        recordChanges[obj] = record[obj];
                    }
                }];
                if ([self.delegate respondsToSelector:@selector(changeManager:gotChanges:forObject:)]) {
                    [self.delegate changeManager:self gotChanges:[recordChanges copy] forObject:managedObject];
                }
                break;
            }
            default:
                break;
        }
    } else {
        for (NSString *key in record.allKeys) {
            if ([self shouldIgnoreKey:key]) {
                continue;
            }
            if (![record[key] isKindOfClass:[CKReference class]]) {
                [managedObject setValue:record[key] forKey:key];
            }
        }
    }
}

- (BOOL)shouldIgnoreKey:(NSString *)key
{
    return ([key isEqualToString:QSCloudKitTimestampKey] || [key isEqualToString:QSCloudKitDeviceUUIDKey]);
}


#pragma mark - Listeners

- (void)targetContextWillSave:(NSNotification *)notification
{
    if (notification.object == self.targetContext && self.isMergingImportedChanges == NO) {
        NSArray *updated = [self.targetContext.updatedObjects allObjects];
        NSMutableDictionary *identifiersAndChanges = [NSMutableDictionary dictionary];
        for (NSManagedObject *object in updated) {
            NSString *identifier = [self uniqueIdentifierForObject:object];
            
            NSMutableArray *changedValueKeys = [NSMutableArray array];
            for (NSString *key in [object.changedValues allKeys]) {
                if (object.entity.attributesByName[key] ||
                    (object.entity.relationshipsByName[key] && object.entity.relationshipsByName[key].isToMany == NO)) {
                    [changedValueKeys addObject:key];
                }
            }
            if (changedValueKeys.count) {
                identifiersAndChanges[identifier] = [changedValueKeys copy];
            }
        }
        
        [self.privateContext performBlock:^{
            [identifiersAndChanges enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull identifier, NSArray *  _Nonnull objectChangedKeys, BOOL * _Nonnull stop) {
                QSSyncedEntity *entity = [self syncedEntityWithOriginObjectIdentifier:identifier];
                NSMutableSet *changedKeys;
                if (entity.changedKeys.length) {
                    changedKeys = [NSMutableSet setWithArray:[entity.changedKeys componentsSeparatedByString:@","]];
                } else {
                    changedKeys = [NSMutableSet set];
                }
                [changedKeys addObjectsFromArray:objectChangedKeys];
                entity.changedKeys = [[changedKeys allObjects] componentsJoinedByString:@","];
            }];
            
            [self savePrivateContext];
        }];
    }
}

- (void)targetContextDidSave:(NSNotification *)notification
{
    if (notification.object == self.targetContext && self.isMergingImportedChanges == NO) {
        NSArray *inserted = [[notification userInfo] objectForKey:NSInsertedObjectsKey];
        NSArray *updated = [[notification userInfo] objectForKey:NSUpdatedObjectsKey];
        NSArray *deleted = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
        
        NSMutableDictionary *insertedIdentifiersAndEntityNames = [NSMutableDictionary dictionary];
        
        for (NSManagedObject *insertedObject in inserted) {
            NSString *identifier = [self uniqueIdentifierForObject:insertedObject];
            insertedIdentifiersAndEntityNames[identifier] = insertedObject.entity.name;
        }
        NSMutableArray *updatedIDs = [NSMutableArray array];
        for (NSManagedObject *updatedObject in updated) {
            NSString *identifier = [self uniqueIdentifierForObject:updatedObject];
            [updatedIDs addObject:identifier];
        }
        
        NSMutableArray *deletedIDs = [NSMutableArray array];
        for (NSManagedObject *deletedObject in deleted) {
            NSString *identifier = [self uniqueIdentifierForObject:deletedObject];
            [deletedIDs addObject:identifier];
        }
        
        BOOL willHaveChanges = NO;
        if (inserted.count || updated.count || deletedIDs.count) {
            willHaveChanges = YES;
        }
        
        [self.privateContext performBlock:^{
            [insertedIdentifiersAndEntityNames enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull objectID, NSString *  _Nonnull entityName, BOOL * _Nonnull stop) {
                [self createSyncedEntityWithIdentifier:objectID entityName:entityName];
            }];
            
            [updatedIDs enumerateObjectsUsingBlock:^(NSString * _Nonnull objectIdentifier, NSUInteger idx, BOOL * _Nonnull stop) {
                QSSyncedEntity *entity = [self syncedEntityWithOriginObjectIdentifier:objectIdentifier];
                if ([entity.state integerValue] == QSSyncedEntityStateSynced && entity.changedKeys.length) {
                    entity.state = @(QSSyncedEntityStateChanged);
                }
                entity.updated = [NSDate date];
            }];
            
            [deletedIDs enumerateObjectsUsingBlock:^(NSString * _Nonnull objectIdentifier, NSUInteger idx, BOOL * _Nonnull stop) {
                QSSyncedEntity *entity = [self syncedEntityWithOriginObjectIdentifier:objectIdentifier];
                entity.state = @(QSSyncedEntityStateDeleted);
                entity.updated = [NSDate date];
            }];
            
            DLog(@"QSCloudKitSynchronizer >> Tracking %ld insertions", (unsigned long)inserted.count);
            DLog(@"QSCloudKitSynchronizer >> Tracking %ld updates", (unsigned long)updatedIDs.count);
            DLog(@"QSCloudKitSynchronizer >> Tracking %ld deletions", (unsigned long)deletedIDs.count);
            
            [self savePrivateContext];
            
            if (willHaveChanges) {
                self.hasChanges = YES;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:QSChangeManagerHasChangesNotification object:self];
                });
            }
        }];
    }
}

#pragma mark - Import context

- (void)configureImportContext
{
    self.targetImportContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.targetImportContext.parentContext = self.targetContext;
}

- (void)clearImportContext
{
    [self.targetImportContext performBlockAndWait:^{
        [self.targetImportContext reset];
    }];
    self.targetImportContext = nil;
}

- (void)mergeChangesIntoTargetContextWithCompletion:(void(^)(NSError *error))completion
{
    DLog(@"Requesting save");
    [self.delegate changeManagerRequestsContextSave:self completion:^(NSError *error){
        if (error) {
            callBlockIfNotNil(completion, nil);
        } else {
            self.mergingImportedChanges = YES;
            DLog(@"Saved. Now importing.");
            [self.delegate changeManager:self didImportChanges:self.targetImportContext completion:^(NSError *error) {
                self.mergingImportedChanges = NO;
                DLog(@"Saved imported changes");
                callBlockIfNotNil(completion, nil);
            }];
        }
    }];
}

- (QSSyncedEntityState)nextStateToSyncAfter:(QSSyncedEntityState)state
{
    return state + 1;
}

#pragma mark - Public

- (void)prepareForImport
{
    [self configureImportContext];
    [self.privateContext performBlockAndWait:^{
        [self deleteAllPendingRelationships];
        [self deleteInsertedButUnmergedEntities];
        [self savePrivateContext];
    }];
}

- (void)saveChangesInRecord:(CKRecord *)record
{
    [self.privateContext performBlock:^{
        QSSyncedEntity *syncedEntity = [self syncedEntityWithIdentifier:record.recordID.recordName];
        if (!syncedEntity) {
            syncedEntity = [self createSyncedEntityForRecord:record];
        }
        
        if ([syncedEntity.state integerValue] == QSSyncedEntityStateDeleted) {
            return;
        }
        
        NSArray *entityChangedKeys = [syncedEntity.changedKeys componentsSeparatedByString:@","];
        NSString *objectID = syncedEntity.originObjectID;
        NSString *entityType = syncedEntity.entityType;
        QSSyncedEntityState entityState = [syncedEntity.state integerValue];
        [self.targetImportContext performBlockAndWait:^{
            NSManagedObject *managedObject = [self managedObjectWithEntityName:entityType identifier:objectID];
            [self applyAttributeChangesInRecord:record toManagedObject:managedObject withSyncedState:entityState changedKeys:entityChangedKeys];
        }];
        
        [self saveRelationshipChangesInRecord:record forEntity:syncedEntity];
        syncedEntity.updated = record[QSCloudKitTimestampKey];
        [self saveRecord:record forSyncedEntity:syncedEntity];
    }];
}

- (void)deleteRecordWithID:(CKRecordID *)recordID
{
    NSString *entityID = recordID.recordName;
    [self.privateContext performBlock:^{
        QSSyncedEntity *syncedEntity = [self syncedEntityWithIdentifier:entityID];
        if (syncedEntity) {
            [self deleteSyncedEntity:syncedEntity];
        }
    }];
}

- (void)persistImportedChangesWithCompletion:(void(^)(NSError *error))completion
{
    [self.privateContext performBlock:^{
        [self applyPendingRelationships];
        [self mergeChangesIntoTargetContextWithCompletion:^(NSError *error) {
            if (error) {
                [self.privateContext reset];
            } else {
                [self updateInsertedEntitiesAndSave];
            }
            callBlockIfNotNil(completion, error);
        }];
    }];
}

- (NSArray *)recordsToUploadWithLimit:(NSInteger)limit
{
    QSSyncedEntityState uploadingState = QSSyncedEntityStateNew;
    __block NSArray *recordsArray = @[];
    if (limit == 0) { limit = NSIntegerMax; }
    
    NSInteger innerLimit = limit;
    while (recordsArray.count < limit && uploadingState < QSSyncedEntityStateDeleted) {
        recordsArray = [recordsArray arrayByAddingObjectsFromArray:[self recordsToUploadWithState:uploadingState limit:innerLimit]];
        uploadingState = [self nextStateToSyncAfter:uploadingState];
        innerLimit = limit - recordsArray.count;
    }
    
    return recordsArray;
}

- (void)didUploadRecords:(NSArray *)savedRecords
{
    [self.privateContext performBlock:^{
        for (CKRecord *record in savedRecords) {
            QSSyncedEntity *savedEntity = [self syncedEntityWithIdentifier:record.recordID.recordName];
            if ([record[QSCloudKitTimestampKey] isEqual:savedEntity.updated]) {
                savedEntity.state = @(QSSyncedEntityStateSynced);
            }
            
            [self saveRecord:record forSyncedEntity:savedEntity];
        }
        
        [self savePrivateContext];
    }];
}

- (NSArray *)recordIDsMarkedForDeletionWithLimit:(NSInteger)limit
{
    __block NSArray *recordIDArray = nil;
    [self.privateContext performBlockAndWait:^{
        NSArray *deletedEntities = [self entitiesWithState:QSSyncedEntityStateDeleted];
        if (deletedEntities.count == 0) {
            recordIDArray = @[];
        } else {
            NSMutableArray *recordIDs = [NSMutableArray array];
            
            for (QSSyncedEntity *entity in [deletedEntities copy]) {
                CKRecord *record = [self recordForSyncedEntity:entity];
                if (record) {
                    [recordIDs addObject:record.recordID];
                } else {
                    [self.privateContext deleteObject:entity];
                }
                
                if (recordIDs.count >= limit) {
                    break;
                }
            }
            
            recordIDArray = recordIDs;
        }
    }];
    return recordIDArray;
}

- (void)didDeleteRecordIDs:(NSArray *)deletedRecordIDs
{
    [self.privateContext performBlock:^{
        for (CKRecordID *recordID in deletedRecordIDs) {
            QSSyncedEntity *deletedEntity = [self syncedEntityWithIdentifier:recordID.recordName];
            if (deletedEntity) {
                [self.privateContext deleteObject:deletedEntity];
            }
        }
        
        [self savePrivateContext];
    }];
}

- (BOOL)hasRecordID:(CKRecordID *)recordID
{
    __block BOOL hasEntity = NO;
    NSString *entityID = recordID.recordName;
    [self.privateContext performBlockAndWait:^{
        QSSyncedEntity *syncedEntity = [self syncedEntityWithIdentifier:entityID];
        if (syncedEntity) {
            hasEntity = YES;
        }
    }];
    return hasEntity;
}

- (void)didFinishImportWithError:(NSError *)error
{
    [self.privateContext performBlockAndWait:^{
        [self savePrivateContext];
        [self updateHasChanges];
    }];
    
    [self clearImportContext];
}

- (void)deleteChangeTracking
{
    [self.stack deleteStore];
    
    [self.targetImportContext reset];
    self.targetImportContext = nil;
    self.targetContext = nil;
}


@end
