//
//  QSCoreDataChangeManager.m
//  Pods
//
//  Created by Manuel Entrena on 10/07/2016.
//
//

#import "QSCoreDataChangeManager.h"
#import "QSSyncedEntityState.h"
#import "QSSyncedEntity.h"
#import "QSRecord.h"
#import "QSOriginObjectIdentifier.h"
#import "QSPendingRelationship.h"
#import "NSManagedObjectContext+QSFetch.h"
#import "QSCloudKitSynchronizer.h"
#import <CloudKit/CloudKit.h>

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
    [self.stack.managedObjectContext save:&error];
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
        }
    }];
}

- (void)performInitialSetup
{
    [self.targetContext performBlock:^{
        NSArray *entities = self.targetContext.persistentStoreCoordinator.managedObjectModel.entities;
        
        for (NSEntityDescription *entityDescription in entities) {
            NSError *error = nil;
            NSArray *objectIDs = [self.targetContext executeFetchRequestWithEntityName:entityDescription.name predicate:nil fetchLimit:0 resultType:NSManagedObjectIDResultType error:&error];
            
            //Create records
            [self.privateContext performBlockAndWait:^{
                for (NSManagedObjectID *objectID in objectIDs) {
                    [self createSyncedEntityForObjectID:objectID entityName:entityDescription.name];
                }
                
                [self savePrivateContext];
            }];
        }
        
        [self.privateContext performBlock:^{
            [self updateHasChanges];
        }];
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
    if (count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hasChanges = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:QSChangeManagerHasChangesNotification object:self];
        });
    }
}

#pragma mark - Persistence management

#pragma mark Entities

- (void)createSyncedEntityForObjectID:(NSManagedObjectID *)objectID entityName:(NSString *)entityName
{
    QSSyncedEntity *syncedEntity = [[QSSyncedEntity alloc] initWithEntity:[NSEntityDescription entityForName:@"QSSyncedEntity" inManagedObjectContext:self.privateContext] insertIntoManagedObjectContext:self.privateContext];
    NSUUID *uuid = [NSUUID UUID];
    syncedEntity.identifier = [NSString stringWithFormat:@"%@.%@", entityName, [uuid UUIDString]];
    syncedEntity.entityType = entityName;
    syncedEntity.state = @(QSSyncedEntityStateNew);
    syncedEntity.updated = [NSDate date];
    QSOriginObjectIdentifier *originID = [[QSOriginObjectIdentifier alloc] initWithEntity:[NSEntityDescription entityForName:@"QSOriginObjectIdentifier" inManagedObjectContext:self.privateContext] insertIntoManagedObjectContext:self.privateContext];
    originID.originObjectID = [objectID.URIRepresentation absoluteString];
    syncedEntity.originIdentifier = originID;
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

- (QSSyncedEntity *)syncedEntityWithOriginObjectIdentifier:(NSString *)objectIdentifier
{
    NSError *error = nil;
    NSArray *fetchedObjects = [self.privateContext executeFetchRequestWithEntityName:@"QSOriginObjectIdentifier"
                                                                           predicate:[NSPredicate predicateWithFormat:@"originObjectID == %@", objectIdentifier]
                                                                               error:&error];
    QSOriginObjectIdentifier *originID = [fetchedObjects firstObject];
    return originID.forSyncedEntity;
}

- (NSDictionary *)referencedSyncedEntitiesByReferenceNameForManagedObject:(NSManagedObject *)object
{
    __block NSDictionary *objectIDsByRelationshipName = nil;
    [self.targetImportContext performBlockAndWait:^{
        objectIDsByRelationshipName = [self referencedObjectIDsByRelationshipNameForManagedObject:object];
    }];
    
    NSMutableDictionary *entitiesByName = [NSMutableDictionary dictionary];
    [objectIDsByRelationshipName enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull relationshipName, NSManagedObjectID *  _Nonnull objectID, BOOL * _Nonnull stop) {
        QSSyncedEntity *entity = [self syncedEntityWithOriginObjectIdentifier:[objectID.URIRepresentation absoluteString]];
        if (entity) {
            entitiesByName[relationshipName] = entity;
        }
    }];
    return [entitiesByName copy];
}

- (void)deleteSyncedEntity:(QSSyncedEntity *)syncedEntity
{
    NSString *originObjectID = syncedEntity.originIdentifier.originObjectID;
    if ([syncedEntity.state integerValue] != QSSyncedEntityStateDeleted && originObjectID) {
        [self.targetImportContext performBlockAndWait:^{
            NSManagedObject *managedObject = [self managedObjectForIDURIRepresentationString:originObjectID];
            if (managedObject) {
                [self.targetImportContext deleteObject:managedObject];
            }
        }];
    }
    
    [self.privateContext deleteObject:syncedEntity];
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
    syncedEntity.state = @(QSSyncedEntityStateSynced);
    
    //Insert managedObject
    __block NSString *objectID = nil;
    [self.targetImportContext performBlockAndWait:^{
        objectID = [self insertManagedObjectWithEntityName:entityName];
    }];
    
    QSOriginObjectIdentifier *originID = [[QSOriginObjectIdentifier alloc] initWithEntity:[NSEntityDescription entityForName:@"QSOriginObjectIdentifier" inManagedObjectContext:self.privateContext] insertIntoManagedObjectContext:self.privateContext];
    originID.originObjectID = objectID;
    syncedEntity.originIdentifier = originID;
    
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
    NSString *objectID = entity.originIdentifier.originObjectID;
    QSSyncedEntityState entityState = [entity.state integerValue];
    NSString *entityType = entity.entityType;
    [self.targetImportContext performBlockAndWait:^{
        originalObject = [self managedObjectForIDURIRepresentationString:objectID];
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

- (NSArray *)entitiesWithPendingRelationships
{
    NSError *error = nil;
    return [self.privateContext executeFetchRequestWithEntityName:@"QSSyncedEntity"
                                                        predicate:[NSPredicate predicateWithFormat:@"pendingRelationships.@count != 0"]
                                                       fetchLimit:0
                                                       resultType:NSManagedObjectResultType
                                                            error:&error];
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

- (void)applyPendingRelationships
{
    NSArray *entities = [self entitiesWithPendingRelationships];
    for (QSSyncedEntity *entity in entities) {
        [self applyPendingRelationshipsForEntity:entity];
    }
}

- (void)applyPendingRelationshipsForEntity:(QSSyncedEntity *)entity
{
    if (entity.pendingRelationships.count) {
        __block NSManagedObject *managedObject;
        NSString *objectID = entity.originIdentifier.originObjectID;
        [self.targetImportContext performBlockAndWait:^{
            managedObject = [self managedObjectForIDURIRepresentationString:objectID];
        }];
        
        if ([entity.state integerValue] == QSSyncedEntityStateChanged) {
            switch (self.mergePolicy) {
                case QSCloudKitSynchronizerMergePolicyServer:
                {
                    for (QSPendingRelationship *pendingRelationship in entity.pendingRelationships) {
                        QSSyncedEntity *targetSyncedEntity = [self syncedEntityWithIdentifier:pendingRelationship.targetIdentifier];
                        NSString *targetObjectID = targetSyncedEntity.originIdentifier.originObjectID;
                        NSString *relationshipName = pendingRelationship.relationshipName;
                        [self.targetImportContext performBlockAndWait:^{
                            NSManagedObject *targetManagedObject = [self managedObjectForIDURIRepresentationString:targetObjectID];
                            [managedObject setValue:targetManagedObject forKey:relationshipName];
                        }];
                    }
                    break;
                }
                case QSCloudKitSynchronizerMergePolicyClient:
                {
                    NSArray *changedKeys = [entity.changedKeys componentsSeparatedByString:@","];
                    for (QSPendingRelationship *pendingRelationship in entity.pendingRelationships) {
                        if ([changedKeys containsObject:pendingRelationship.relationshipName] == NO) {
                            QSSyncedEntity *targetSyncedEntity = [self syncedEntityWithIdentifier:pendingRelationship.targetIdentifier];
                            NSString *targetObjectID = targetSyncedEntity.originIdentifier.originObjectID;
                            NSString *relationshipName = pendingRelationship.relationshipName;
                            [self.targetImportContext performBlockAndWait:^{
                                NSManagedObject *targetManagedObject = [self managedObjectForIDURIRepresentationString:targetObjectID];
                                [managedObject setValue:targetManagedObject forKey:relationshipName];
                            }];
                        }
                    }
                    break;
                }
                case QSCloudKitSynchronizerMergePolicyCustom:
                {
                    NSMutableDictionary *relationshipDictionary = [NSMutableDictionary dictionary];
                    for (QSPendingRelationship *pendingRelationship in entity.pendingRelationships) {
                        QSSyncedEntity *targetSyncedEntity = [self syncedEntityWithIdentifier:pendingRelationship.targetIdentifier];
                        NSString *targetObjectID = targetSyncedEntity.originIdentifier.originObjectID;
                        NSString *relationshipName = pendingRelationship.relationshipName;
                        [self.targetImportContext performBlockAndWait:^{
                            NSManagedObject *targetManagedObject = [self managedObjectForIDURIRepresentationString:targetObjectID];
                            relationshipDictionary[relationshipName] = targetManagedObject;
                        }];
                    }
                    
                    if ([self.delegate respondsToSelector:@selector(changeManager:gotChanges:forObject:)]) {
                        [self.targetImportContext performBlockAndWait:^{
                            [self.delegate changeManager:self gotChanges:relationshipDictionary forObject:managedObject];
                        }];
                    }
                }
                    
                default:
                    break;
            }
        } else {
            for (QSPendingRelationship *pendingRelationship in entity.pendingRelationships) {
                QSSyncedEntity *targetSyncedEntity = [self syncedEntityWithIdentifier:pendingRelationship.targetIdentifier];
                NSString *targetObjectID = targetSyncedEntity.originIdentifier.originObjectID;
                NSString *relationshipName = pendingRelationship.relationshipName;
                if (targetObjectID && relationshipName) {
                    [self.targetImportContext performBlockAndWait:^{
                        NSManagedObject *targetManagedObject = [self managedObjectForIDURIRepresentationString:targetObjectID];
                        [managedObject setValue:targetManagedObject forKey:relationshipName];
                    }];
                }
            }
        }
        
        for (QSPendingRelationship *pendingRelationship in [entity.pendingRelationships copy]) {
            [self.privateContext deleteObject:pendingRelationship];
        }
        entity.pendingRelationships = nil;
    }
}

#pragma mark Target context

- (NSString *)insertManagedObjectWithEntityName:(NSString *)entityName
{
    NSManagedObject *managedObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.targetImportContext];
    NSError *error = nil;
    [self.targetImportContext obtainPermanentIDsForObjects:@[managedObject] error:&error];
    return [managedObject.objectID.URIRepresentation absoluteString];
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

- (NSDictionary *)referencedObjectIDsByRelationshipNameForManagedObject:(NSManagedObject *)object
{
    NSDictionary *relationships = [object.entity relationshipsByName];
    
    NSMutableDictionary *objectIDs = [NSMutableDictionary dictionary];
    for (NSRelationshipDescription *relationshipDescription in [relationships allValues]) {
        if (relationshipDescription.toMany == NO) {
            NSManagedObject *referencedObject = [object valueForKey:relationshipDescription.name];
            if (referencedObject) {
                objectIDs[relationshipDescription.name] = referencedObject.objectID;
            }
        }
    }
    
    return [objectIDs copy];
}

- (void)applyAttributeChangesInRecord:(CKRecord *)record toManagedObject:(NSManagedObject *)managedObject withSyncedState:(QSSyncedEntityState)state changedKeys:(NSArray *)entityChangedKeys
{
    if (state == QSSyncedEntityStateChanged) {
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
                        if (![entityChangedKeys containsObject:key]) {
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
            NSString *identifier = [object.objectID.URIRepresentation absoluteString];
            identifiersAndChanges[identifier] = [object.changedValues allKeys];
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
            insertedIdentifiersAndEntityNames[insertedObject.objectID] = insertedObject.entity.name;
        }
        NSArray *updatedIDs = [updated valueForKey:@"objectID"];
        NSArray *deletedIDs = [deleted valueForKey:@"objectID"];
        BOOL willHaveChanges = NO;
        if (inserted.count || updated.count || deletedIDs.count) {
            willHaveChanges = YES;
        }
        
        [self.privateContext performBlock:^{
            [insertedIdentifiersAndEntityNames enumerateKeysAndObjectsUsingBlock:^(NSManagedObjectID *  _Nonnull objectID, NSString *  _Nonnull entityName, BOOL * _Nonnull stop) {
                [self createSyncedEntityForObjectID:objectID entityName:entityName];
            }];
            
            [updatedIDs enumerateObjectsUsingBlock:^(NSManagedObjectID * _Nonnull objectID, NSUInteger idx, BOOL * _Nonnull stop) {
                QSSyncedEntity *entity = [self syncedEntityWithOriginObjectIdentifier:[objectID.URIRepresentation absoluteString]];
                if ([entity.state integerValue] == QSSyncedEntityStateSynced) {
                    entity.state = @(QSSyncedEntityStateChanged);
                }
                entity.updated = [NSDate date];
            }];
            
            [deletedIDs enumerateObjectsUsingBlock:^(NSManagedObjectID * _Nonnull objectID, NSUInteger idx, BOOL * _Nonnull stop) {
                QSSyncedEntity *entity = [self syncedEntityWithOriginObjectIdentifier:[objectID.URIRepresentation absoluteString]];
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
    [self.delegate changeManagerRequestsContextSave:self completion:^(NSError *error){
        if (error) {
            [self.privateContext performBlockAndWait:^{
                [self.privateContext reset];
            }];
            completion(error);
        } else {
            self.mergingImportedChanges = YES;
            [self.delegate changeManager:self didImportChanges:self.targetImportContext completion:^(NSError *error) {
                self.mergingImportedChanges = NO;
                if (!error) {
                    [self savePrivateContext];
                    completion(nil);
                } else {
                    [self.privateContext performBlockAndWait:^{
                        [self.privateContext reset];
                    }];
                    completion(error);
                }
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
}

- (void)saveChangesInRecord:(CKRecord *)record
{
    QSSyncedEntity *syncedEntity = [self syncedEntityWithIdentifier:record.recordID.recordName];
    if (!syncedEntity) {
        syncedEntity = [self createSyncedEntityForRecord:record];
    }
    
    if ([syncedEntity.state integerValue] == QSSyncedEntityStateDeleted) {
        return;
    }
    
    NSArray *entityChangedKeys = [syncedEntity.changedKeys componentsSeparatedByString:@","];
    NSString *objectID = syncedEntity.originIdentifier.originObjectID;
    QSSyncedEntityState entityState = [syncedEntity.state integerValue];
    [self.targetImportContext performBlockAndWait:^{
        NSManagedObject *managedObject = [self managedObjectForIDURIRepresentationString:objectID];
        [self applyAttributeChangesInRecord:record toManagedObject:managedObject withSyncedState:entityState changedKeys:entityChangedKeys];
    }];
    
    [self saveRelationshipChangesInRecord:record forEntity:syncedEntity];
    syncedEntity.updated = record[QSCloudKitTimestampKey];
    [self saveRecord:record forSyncedEntity:syncedEntity];
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

- (NSArray *)recordIDsMarkedForDeletion
{
    __block NSArray *recordIDArray = nil;
    [self.privateContext performBlockAndWait:^{
        NSArray *deletedEntities = [self entitiesWithState:QSSyncedEntityStateDeleted];
        if (deletedEntities.count == 0) {
            recordIDArray = @[];
        } else {
            NSMutableArray *recordIDs = [NSMutableArray array];
            
            for (QSSyncedEntity *entity in deletedEntities) {
                CKRecord *record = [self recordForSyncedEntity:entity];
                [recordIDs addObject:record.recordID];
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

- (void)persistImportedChangesWithCompletion:(void(^)(NSError *error))completion
{
    [self.privateContext performBlock:^{
        [self applyPendingRelationships];
        [self mergeChangesIntoTargetContextWithCompletion:completion];
    }];
}

- (void)didFinishImportWithError:(NSError *)error
{
    if (!error) {
        self.hasChanges = NO;
    }
    
    [self.privateContext performBlockAndWait:^{
        [self savePrivateContext];
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
