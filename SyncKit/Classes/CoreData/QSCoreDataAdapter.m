//
//  QSCoreDataAdapter.m
//  Pods
//
//  Created by Manuel Entrena on 10/07/2016.
//
//

#import "QSCoreDataAdapter.h"
#import "QSPrimaryKey.h"
#import "QSSyncedEntityState.h"
#import "QSSyncedEntity+CoreDataClass.h"
#import "QSRecord+CoreDataClass.h"
#import "QSPendingRelationship+CoreDataClass.h"
#import "NSManagedObjectContext+QSFetch.h"
#import "QSCloudKitSynchronizer.h"
#import "SyncKitLog.h"
#import "QSTempFileManager.h"
#import "QSServerToken+CoreDataClass.h"
#import <CloudKit/CloudKit.h>

#define callBlockIfNotNil(block, ...) if (block){block(__VA_ARGS__);}
static NSString * const QSCloudKitTimestampKey = @"QSCloudKitTimestampKey";
static const NSString * QSCoreDataAdapterShareRelationshipKey = @"com.syncKit.shareRelationship";

@interface QSQueryData : NSObject

@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) CKRecord *record;
@property (nonatomic, strong) NSString *entityType;
@property (nonatomic, strong) NSArray *changedKeys;
@property (nonatomic, strong) NSNumber *state;
@property (nonatomic, strong) NSDictionary *relationshipDictionary;

- (instancetype)initWithIdentifier:(NSString *)identifier record:(CKRecord *)record entityType:(NSString *)entityType changedKeys:(NSArray *)changedKeys entityState:(NSNumber *)entityState relationships:(NSDictionary *)relationships;

@end

@implementation QSQueryData

- (instancetype)initWithIdentifier:(NSString *)identifier record:(CKRecord *)record entityType:(NSString *)entityType changedKeys:(NSArray *)changedKeys entityState:(NSNumber *)entityState relationships:(NSDictionary *)relationships
{
    self = [super init];
    if (self) {
        self.identifier = identifier;
        self.record = record;
        self.entityType = entityType;
        self.changedKeys = changedKeys;
        self.state = entityState;
        self.relationshipDictionary = relationships;
    }
    return self;
}

@end

@interface QSChildRelationship: NSObject

@property (nonatomic, strong) NSString *parentEntityName;
@property (nonatomic, strong) NSString *childEntityName;
@property (nonatomic, strong) NSString *childParentKey;

- (instancetype)initWithParent:(NSString *)parent child:(NSString *)child parentKey:(NSString *)parentKey;

@end

@implementation QSChildRelationship

- (instancetype)initWithParent:(NSString *)parent child:(NSString *)child parentKey:(NSString *)parentKey
{
    self = [super init];
    if (self) {
        self.parentEntityName = parent;
        self.childEntityName = child;
        self.childParentKey = parentKey;
    }
    return self;
}

@end


@interface QSCoreDataAdapter ()

@property (nonatomic, readwrite, strong) QSCoreDataStack *stack;
@property (nonatomic, strong) NSManagedObjectContext *privateContext;
@property (nonatomic, strong) NSManagedObjectContext *targetImportContext;
@property (nonatomic, assign) BOOL hasChanges;
@property (nonatomic, assign, getter=isMergingImportedChanges) BOOL mergingImportedChanges;
@property (nonatomic, strong, readwrite) NSManagedObjectContext *targetContext;
@property (nonatomic, readwrite) id<QSCoreDataAdapterDelegate> delegate;
@property (nonatomic, readwrite, strong) CKRecordZoneID *recordZoneID;
@property (nonatomic, strong) NSDictionary *entityPrimaryKeys;
@property (nonatomic, strong) QSTempFileManager *tempFileManager;
@property (nonatomic, strong) NSDictionary *childrenRelationships;

@end

@implementation QSCoreDataAdapter

+ (NSManagedObjectModel *)persistenceModel
{
    NSURL *modelURL = [[NSBundle bundleForClass:[QSCoreDataAdapter class]] URLForResource:@"QSCloudKitSyncModel" withExtension:@"momd"];
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
}

- (instancetype)initWithPersistenceStack:(QSCoreDataStack *)stack targetContext:(NSManagedObjectContext *)targetContext recordZoneID:(CKRecordZoneID *)zoneID delegate:(id<QSCoreDataAdapterDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.stack = stack;
        self.targetContext = targetContext;
        self.delegate = delegate;
        self.recordZoneID = zoneID;
        self.tempFileManager = [[QSTempFileManager alloc] init];
        
        self.privateContext = stack.managedObjectContext;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(targetContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:self.targetContext];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(targetContextWillSave:) name:NSManagedObjectContextWillSaveNotification object:self.targetContext];
        
        [self setupPrimaryKeysLookup];
        [self setupChildrenRelationshipsLookup];
        
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
                    [[NSNotificationCenter defaultCenter] postNotificationName:QSModelAdapterHasChangesNotification object:self];
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
            NSString *primaryKey = [self identifierFieldNameForEntityOfType:entityDescription.name];
            NSArray *objectIDs;
            
            //Get object identifiers using primary key
            objectIDs = [self.targetContext executeFetchRequestWithEntityName:entityDescription.name predicate:nil fetchLimit:0 resultType:NSDictionaryResultType propertiesToFetch:@[primaryKey] error:&error];
            objectIDs = [objectIDs valueForKey:primaryKey];
            
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
                    [[NSNotificationCenter defaultCenter] postNotificationName:QSModelAdapterHasChangesNotification object:self];
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
            Class entityClass = NSClassFromString(entityDescription.managedObjectClassName);
            if ([entityClass conformsToProtocol:@protocol(QSPrimaryKey)]) {
                primaryKeys[entityDescription.name] = [entityClass primaryKey];
            } else {
                NSAssert(false, @"QSPrimaryKey protocol not implemented for class: %@", entityDescription.managedObjectClassName);
            }
        }
        self.entityPrimaryKeys = [primaryKeys copy];
    }];
}

- (void)setupChildrenRelationshipsLookup
{
    NSMutableDictionary *relationships = [NSMutableDictionary dictionary];
    [self.targetContext performBlockAndWait:^{
        NSArray *entities = self.targetContext.persistentStoreCoordinator.managedObjectModel.entities;
        for (NSEntityDescription *entityDescription in entities) {
            Class entityClass = NSClassFromString(entityDescription.managedObjectClassName);
            if ([entityClass conformsToProtocol:@protocol(QSParentKey)]) {
                NSString *parentKey = [entityClass parentKey];
                NSRelationshipDescription *relationshipDescription = entityDescription.relationshipsByName[parentKey];
                NSEntityDescription *parentEntity = relationshipDescription.destinationEntity;
                QSChildRelationship *relationship = [[QSChildRelationship alloc] initWithParent:parentEntity.name child:entityDescription.name parentKey:parentKey];
                NSMutableArray *children = relationships[parentEntity.name];
                if (!children) {
                    children = [NSMutableArray array];
                    relationships[parentEntity.name] = children;
                }
                [children addObject:relationship];
            }
        }
    }];
    self.childrenRelationships = [relationships copy];
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
    
    return [record.recordID.recordName substringFromIndex:entityType.length + 1];
}

- (NSString *)getThreadSafePrimaryKeyValueForManagedObject:(NSManagedObject *)managedObject
{
    __block NSString *identifier = nil;
    [managedObject.managedObjectContext performBlockAndWait:^{
        identifier = [self uniqueIdentifierForObject:managedObject];
    }];
    return identifier;
}

#pragma mark - Persistence management

#pragma mark Entities

- (void)createSyncedEntityWithIdentifier:(NSString *)identifier entityName:(NSString *)entityName
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"QSSyncedEntity" inManagedObjectContext:self.privateContext];
    QSSyncedEntity *syncedEntity = [[QSSyncedEntity alloc] initWithEntity:entityDescription insertIntoManagedObjectContext:self.privateContext];
    
    syncedEntity.entityType = entityName;
    syncedEntity.state = @(QSSyncedEntityStateNew);
    syncedEntity.updated = [NSDate date];
    syncedEntity.originObjectID = identifier;
    
    syncedEntity.identifier = [NSString stringWithFormat:@"%@.%@", entityName, identifier];
}

- (NSArray *)entitiesWithState:(QSSyncedEntityState)state
{
    NSError *error = nil;
    return [self.privateContext executeFetchRequestWithEntityName:@"QSSyncedEntity"
                                                        predicate:[NSPredicate predicateWithFormat:@"state == %lud", state]
                                                            error:&error];
}

- (NSArray *)syncedEntitiesWithIdentifiers:(NSArray<NSString *> *)identifiers
{
    NSError *error = nil;
    return [self.privateContext executeFetchRequestWithEntityName:@"QSSyncedEntity"
                                                                           predicate:[NSPredicate predicateWithFormat:@"identifier IN %@", identifiers]
                                                                          fetchLimit:0
                                                                             preload:YES
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

- (NSDictionary *)referencedSyncedEntitiesByReferenceNameForManagedObject:(NSManagedObject *)object objectContext:(NSManagedObjectContext *)objectContext
{
    __block NSDictionary *objectIDsByRelationshipName = nil;
    [objectContext performBlockAndWait:^{
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

- (void)deleteSyncedEntities:(NSArray<QSSyncedEntity *> *)syncedEntities
{
    NSMutableDictionary *identifiersByType = [NSMutableDictionary dictionary];
    for (QSSyncedEntity *syncedEntity in syncedEntities) {
        
        NSString *originObjectID = syncedEntity.originObjectID;
        if (![syncedEntity.entityType isEqualToString:@"CKShare"] &&
            [syncedEntity.state integerValue] != QSSyncedEntityStateDeleted &&
            originObjectID) {
            NSMutableArray *identifiers = identifiersByType[syncedEntity.entityType];
            if (!identifiers) {
                identifiers = [NSMutableArray array];
                identifiersByType[syncedEntity.entityType] = identifiers;
            }
            [identifiers addObject:originObjectID];
        }
        
        [self.privateContext deleteObject:syncedEntity];
    }
    
    [self.targetImportContext performBlockAndWait:^{
        for (NSString *entityType in [identifiersByType allKeys]) {
            NSArray *objects = [self managedObjectsWithEntityName:entityType identifiers:identifiersByType[entityType] context:self.targetImportContext];
            for (NSManagedObject *object in objects) {
                [self.targetImportContext deleteObject:object];
            }
        }
    }];
}

- (void)deleteSyncedEntity:(QSSyncedEntity *)syncedEntity
{
    NSString *originObjectID = syncedEntity.originObjectID;
    if ([syncedEntity.state integerValue] != QSSyncedEntityStateDeleted && originObjectID) {
        NSString *entityName = syncedEntity.entityType;
        [self.targetImportContext performBlockAndWait:^{
            NSManagedObject *managedObject = [self managedObjectWithEntityName:entityName identifier:originObjectID context:self.targetImportContext];
            
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
    qsRecord.encodedRecord = [self encodedRecord:record onlySystemFields:YES];
}

- (void)saveShare:(CKShare *)record forSyncedEntity:(QSSyncedEntity *)entity NS_AVAILABLE(10.12, 10.0)
{
    QSRecord *qsRecord;
    QSSyncedEntity *entityForShare = entity.share;
    if (!entityForShare) {
        entityForShare = [self createSyncedEntityForShare:record];
        
        qsRecord = [[QSRecord alloc] initWithEntity:[NSEntityDescription entityForName:@"QSRecord" inManagedObjectContext:self.privateContext] insertIntoManagedObjectContext:self.privateContext];
        
        entityForShare.record = qsRecord;
        entity.share = entityForShare;
    } else {
        qsRecord = entityForShare.record;
    }
    
    qsRecord.encodedRecord = [self encodedRecord:record onlySystemFields:NO];
}

- (NSData *)encodedRecord:(CKRecord *)record onlySystemFields:(BOOL)onlySystemFields
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    if (onlySystemFields) {
        [record encodeSystemFieldsWithCoder:archiver];
    } else {
        [record encodeWithCoder:archiver];
    }
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

- (CKShare *)shareForSyncedEntity:(QSSyncedEntity *)entity NS_AVAILABLE(10.12, 10.0)
{
    CKShare *share = nil;
    if (entity.share && entity.share.record) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:entity.share.record.encodedRecord];
        share = [[CKShare alloc] initWithCoder:unarchiver];
        [unarchiver finishDecoding];
    }
    return share;
}

- (QSSyncedEntity *)createSyncedEntityForShare:(CKShare *)share NS_AVAILABLE(10.12, 10.0)
{
    QSSyncedEntity *entityForShare = [[QSSyncedEntity alloc] initWithEntity:[NSEntityDescription entityForName:@"QSSyncedEntity"
                                                                        inManagedObjectContext:self.privateContext]
                             insertIntoManagedObjectContext:self.privateContext];
    
    entityForShare.entityType = @"CKShare";
    entityForShare.identifier = share.recordID.recordName;
    entityForShare.updated = [NSDate date];
    entityForShare.state = @(QSSyncedEntityStateSynced);
    return entityForShare;
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
        [object setValue:objectID forKey:[self identifierFieldNameForEntityOfType:entityName]];
    }];
    
    syncedEntity.originObjectID = objectID;
    
    return syncedEntity;
}

- (CKRecord *)recordToUploadForSyncedEntity:(QSSyncedEntity *)entity context:(NSManagedObjectContext *)objectContext parentSyncedEntity:(QSSyncedEntity **)parentSyncedEntity;
{
    if (!entity) {
        return nil;
    }
    
    CKRecord *record = [self recordForSyncedEntity:entity];
    if (!record) {
        record = [[CKRecord alloc] initWithRecordType:entity.entityType recordID:[[CKRecordID alloc] initWithRecordName:entity.identifier zoneID:self.recordZoneID]];
    }
    
    //To assign only attributes that have changed, if state == changed. Assign everything if state == new
    NSArray *changedKeys = [entity.changedKeys componentsSeparatedByString:@","];
    
    __block NSManagedObject *originalObject;
    __block NSEntityDescription *entityDescription;
    NSString *objectID = entity.originObjectID;
    QSSyncedEntityState entityState = [entity.state integerValue];
    NSString *entityType = entity.entityType;
    [objectContext performBlockAndWait:^{
        originalObject = [self managedObjectWithEntityName:entityType identifier:objectID context:objectContext];
        entityDescription = [NSEntityDescription entityForName:entityType inManagedObjectContext:objectContext];
        NSString *primaryKey = [self identifierFieldNameForEntityOfType:entityType];
        //Add attributes
        [[entityDescription attributesByName] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull attributeName, NSAttributeDescription * _Nonnull attributeDescription, BOOL * _Nonnull stop) {
            if ((entityState == QSSyncedEntityStateNew || [changedKeys containsObject:attributeName]) && [primaryKey isEqualToString:attributeName] == NO) {
                
                id value = [originalObject valueForKey:attributeName];
                if (attributeDescription.attributeType == NSBinaryDataAttributeType && value && !self.forceDataTypeInsteadOfAsset) {
                    NSURL *fileURL = [self.tempFileManager storeData:(NSData *)value];
                    CKAsset *asset = [[CKAsset alloc] initWithFileURL:fileURL];
                    record[attributeName] = asset;
                } else if (attributeDescription.attributeType == NSTransformableAttributeType && value) {
                    record[attributeName] = [self transformedValueFor:value valueTransformerName:attributeDescription.valueTransformerName];
                } else {
                    record[attributeName] = value;
                }
            }
        }];
    }];
    
    Class objectClass = NSClassFromString(entityDescription.managedObjectClassName);
    NSString *parentKey = nil;
    if ([objectClass conformsToProtocol:@protocol(QSParentKey)]) {
        parentKey = [objectClass parentKey];
    }
    
    NSDictionary *referencedEntities = [self referencedSyncedEntitiesByReferenceNameForManagedObject:originalObject objectContext:objectContext];
    [referencedEntities enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull relationshipName, QSSyncedEntity  * _Nonnull entity, BOOL * _Nonnull stop) {
        if (entityState == QSSyncedEntityStateNew || [changedKeys containsObject:relationshipName]) {
            CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName:entity.identifier zoneID:self.recordZoneID];
            // if we set the parent we must make the action .deleteSelf, otherwise we get errors if we ever try to delete the parent record
            CKReferenceAction action = [parentKey isEqualToString:relationshipName] ? CKReferenceActionDeleteSelf : CKReferenceActionNone;
            CKReference *recordReference = [[CKReference alloc] initWithRecordID:recordID action:action];
            record[relationshipName] = recordReference;
        }
    }];
    
    if (parentKey && (entityState == QSSyncedEntityStateNew || [changedKeys containsObject:parentKey])) {
        CKReference *reference = record[parentKey];
        if (reference.recordID) {
            // For the parent reference we have to use action .none though, even if we must use .deleteSelf for the attribute (see ^)
            record.parent = [[CKReference alloc] initWithRecordID:reference.recordID action:CKReferenceActionNone];
            if (parentSyncedEntity) {
                *parentSyncedEntity = referencedEntities[parentKey];
            }
        }
    }
    
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
            NSMutableSet *includedEntityIDs = [NSMutableSet set];
            
            while (records.count < limit && pending.count) {
                QSSyncedEntity *entity = [pending lastObject];
                
                while (entity != nil && [entity.state integerValue] == state && ![includedEntityIDs containsObject:entity.identifier]) {
                    QSSyncedEntity *parentEntity = nil;
                    [pending removeObject:entity];
                    CKRecord *record = [self recordToUploadForSyncedEntity:entity context:self.targetContext parentSyncedEntity:&parentEntity];
                    [records addObject:record];
                    [includedEntityIDs addObject:entity.identifier];
                    entity = parentEntity;
                }
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

- (void)saveRelationshipChangesInRecord:(CKRecord *)record withNames:(NSArray *)relationshipsToSave forEntity:(QSSyncedEntity *)entity
{
    for (NSString *key in relationshipsToSave) {
        
        if ([record[key] isKindOfClass:[CKReference class]]) {
            CKReference *reference = record[key];
            QSPendingRelationship *relationship = [NSEntityDescription insertNewObjectForEntityForName:@"QSPendingRelationship" inManagedObjectContext:self.privateContext];
            relationship.relationshipName = key;
            relationship.targetIdentifier = reference.recordID.recordName;
            relationship.forEntity = entity;
        }
    }
}

- (void)saveShareRelationshipForEntity:(QSSyncedEntity *)entity record:(CKRecord *)record
{
    if (record.share) {
        QSPendingRelationship *relationship = [NSEntityDescription insertNewObjectForEntityForName:@"QSPendingRelationship" inManagedObjectContext:self.privateContext];
        relationship.relationshipName = @"share";
        relationship.targetIdentifier = record.share.recordID.recordName;
        relationship.forEntity = entity;
    }
}

// For relationships that are nil, this will make the property nil on the object. For those that have a value, this will return their names
- (NSArray *)relationshipsToSaveForObject:(NSManagedObject *)object record:(CKRecord *)record
{
    NSMutableArray *relationshipsToSave = [NSMutableArray array];
    for (NSString *relationshipName in [object.entity.relationshipsByName allKeys]) {
        if (object.entity.relationshipsByName[relationshipName].isToMany) {
            continue;
        }
        
        if (record[relationshipName]) {
            [relationshipsToSave addObject:relationshipName];
        } else {
            [object setValue:nil forKey:relationshipName];
        }
    }
    
    return [relationshipsToSave copy];
}

- (QSPendingRelationship *)pendingShareRelationshipForEntity:(QSSyncedEntity *)entity
{
    for (QSPendingRelationship *pendingRelationship in entity.pendingRelationships) {
        if ([pendingRelationship.relationshipName isEqualToString:@"share"]) {
            return pendingRelationship;
        }
    }
    return nil;
}

- (NSDictionary *)pendingRelationshipTargetIdentifiersForEntity:(QSSyncedEntity *)entity
{
    NSMutableDictionary *relationships = [NSMutableDictionary dictionary];
    for (QSPendingRelationship *pendingRelationship in entity.pendingRelationships) {
        
        if ([pendingRelationship.relationshipName isEqualToString:@"share"]) {
            continue;
        }
        
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
    
    NSMutableDictionary *queriesByEntityType = [NSMutableDictionary dictionary];
    for (QSSyncedEntity *entity in entities) {
        QSPendingRelationship *pendingShare = [self pendingShareRelationshipForEntity:entity];
        
        if (pendingShare) {
            QSSyncedEntity *share = [self syncedEntityWithIdentifier:pendingShare.targetIdentifier];
            entity.share = share;
        }
        
        QSQueryData *query = [[QSQueryData alloc] initWithIdentifier:entity.originObjectID
                                                              record:nil
                                                          entityType:entity.entityType
                                                         changedKeys:[entity.changedKeys componentsSeparatedByString:@","]
                                                         entityState:entity.state
                                                        relationships:[self pendingRelationshipTargetIdentifiersForEntity:entity]];
        
        NSMutableDictionary *queries = queriesByEntityType[entity.entityType];
        if (!queries) {
            queries = [NSMutableDictionary dictionary];
            queriesByEntityType[entity.entityType] = queries;
        }
        queries[entity.originObjectID] = query;
        
        for (QSPendingRelationship *pendingRelationship in [entity.pendingRelationships copy]) {
            [self.privateContext deleteObject:pendingRelationship];
        }
    }
    
    [self.targetImportContext performBlockAndWait:^{
        [self targetApplyPendingRelationships:queriesByEntityType context:self.targetImportContext];
    }];
}

- (void)targetApplyPendingRelationships:(NSDictionary *)dictionary context:(NSManagedObjectContext *)objectContext
{
    DLog(@"Target apply pending relationships");
    
    for (NSString *entityType in [dictionary allKeys]) {
        NSDictionary *queries = dictionary[entityType];
        NSArray *objects = [self managedObjectsWithEntityName:entityType identifiers:[queries allKeys] context:objectContext];
        for (NSManagedObject *managedObject in objects) {
            QSQueryData *query = queries[[self uniqueIdentifierForObject:managedObject]];
            for (NSString *relationshipName in [query.relationshipDictionary allKeys]) {
                NSDictionary *targetObjectInfo = query.relationshipDictionary[relationshipName];
                NSString *targetIdentifier = targetObjectInfo[@"originObjectID"];
                NSString *targetEntityType = targetObjectInfo[@"entityType"];
                if ([query.state integerValue] > QSSyncedEntityStateChanged //Not changed, not new
                    ||
                    self.mergePolicy == QSModelAdapterMergePolicyServer
                    ||
                    (self.mergePolicy == QSModelAdapterMergePolicyClient &&
                     (![query.changedKeys containsObject:relationshipName] || ([query.state integerValue] == QSSyncedEntityStateNew && [managedObject valueForKey:relationshipName] == nil))
                     )
                    ) {
                    
                    NSManagedObject *targetManagedObject = [self managedObjectWithEntityName:targetEntityType identifier:targetIdentifier context:objectContext];
                    [managedObject setValue:targetManagedObject forKey:relationshipName];
                } else if (self.mergePolicy == QSModelAdapterMergePolicyCustom) {
                    NSManagedObject *targetManagedObject = [self managedObjectWithEntityName:targetEntityType identifier:targetIdentifier context:objectContext];
                    if ([self.conflictDelegate respondsToSelector:@selector(coreDataAdapter:gotChanges:forObject:)]) {
                        [self.conflictDelegate coreDataAdapter:self gotChanges:@{relationshipName: targetManagedObject} forObject:managedObject];
                    }
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

- (NSManagedObject *)managedObjectWithEntityName:(NSString *)entityName identifier:(NSString *)identifier context:(NSManagedObjectContext *)objectContext
{
    
    return [self managedObjectWithEntityName:entityName
                                         key:[self identifierFieldNameForEntityOfType:entityName]
                                  identifier:identifier
                                     context:objectContext];
}

- (NSArray<NSManagedObject *> *)managedObjectsWithEntityName:(NSString *)entityName identifiers:(NSArray<NSString *> *)identifiers context:(NSManagedObjectContext *)objectContext
{
    
    NSString *identifierKey = [self identifierFieldNameForEntityOfType:entityName];
    NSError *error = nil;
    NSArray *results = [objectContext executeFetchRequestWithEntityName:entityName predicate:[NSPredicate predicateWithFormat:@"%K IN %@", identifierKey, identifiers] error:&error];
    return results;
}

- (NSManagedObject *)managedObjectWithEntityName:(NSString *)entityName key:(NSString *)identifierKey identifier:(NSString *)identifier context:(NSManagedObjectContext *)objectContext
{
    if (!entityName || !identifierKey || !identifier) {
        return nil;
    }
    
    NSError *error = nil;
    NSArray *results = [objectContext executeFetchRequestWithEntityName:entityName predicate:[NSPredicate predicateWithFormat:@"%K == %@", identifierKey, identifier] error:&error];
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
    NSString *primaryKey = [self identifierFieldNameForEntityOfType:managedObject.entity.name];
    if (state == QSSyncedEntityStateChanged || state == QSSyncedEntityStateNew) {
        switch (self.mergePolicy) {
            case QSModelAdapterMergePolicyServer:
            {
                //Add attributes
                [[managedObject.entity attributesByName] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull attributeName, NSAttributeDescription * _Nonnull attributeDescription, BOOL * _Nonnull stop) {
                    if (![self shouldIgnoreKey:attributeName] && ![record[attributeName] isKindOfClass:[CKReference class]] && ![primaryKey isEqualToString:attributeName]) {
                        
                        [self assignAttributeValue:record[attributeName] toManagedObject:managedObject attributeName:attributeName];
                    }
                }];
                break;
            }
            case QSModelAdapterMergePolicyClient:
            {
                //Add attributes
                [[managedObject.entity attributesByName] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull attributeName, NSAttributeDescription * _Nonnull attributeDescription, BOOL * _Nonnull stop) {
                    if (![self shouldIgnoreKey:attributeName] &&
                        ![record[attributeName] isKindOfClass:[CKReference class]] &&
                        ![entityChangedKeys containsObject:attributeName] &&
                        state != QSSyncedEntityStateNew &&
                        ![primaryKey isEqualToString:attributeName]) {
                        
                        [self assignAttributeValue:record[attributeName] toManagedObject:managedObject attributeName:attributeName];
                    }
                }];
                
                break;
            }
            case QSModelAdapterMergePolicyCustom:
            {
                NSMutableDictionary *recordChanges = [NSMutableDictionary dictionary];
                [[managedObject.entity attributesByName] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull attributeName, NSAttributeDescription * _Nonnull attributeDescription, BOOL * _Nonnull stop) {
                    if (![record[attributeName] isKindOfClass:[CKReference class]] &&
                        ![primaryKey isEqualToString:attributeName]) {
                        if ([record[attributeName] isKindOfClass:[CKAsset class]]) {
                            CKAsset *asset = record[attributeName];
                            recordChanges[attributeName] = [NSData dataWithContentsOfURL:asset.fileURL];
                        } else {
                            recordChanges[attributeName] = record[attributeName] ?: [NSNull null];
                        }
                    }
                }];
                
                if ([self.conflictDelegate respondsToSelector:@selector(coreDataAdapter:gotChanges:forObject:)]) {
                    [self.conflictDelegate coreDataAdapter:self gotChanges:[recordChanges copy] forObject:managedObject];
                }
                break;
            }
            default:
                break;
        }
    } else {
        
        //Add attributes
        [[managedObject.entity attributesByName] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull attributeName, NSAttributeDescription * _Nonnull attributeDescription, BOOL * _Nonnull stop) {
            if (![self shouldIgnoreKey:attributeName] && ![record[attributeName] isKindOfClass:[CKReference class]] && ![primaryKey isEqualToString:attributeName]) {
                [self assignAttributeValue:record[attributeName] toManagedObject:managedObject attributeName:attributeName];
            }
        }];
    }
}

- (void)assignAttributeValue:(id)value toManagedObject:(NSManagedObject *)object attributeName:(NSString *)attributeName
{
    if ([value isKindOfClass:[CKAsset class]]) {
        
        NSData *data = [NSData dataWithContentsOfURL:[(CKAsset *)value fileURL]];
        [object setValue:data forKey:attributeName];
        
    } else {
        
        NSAttributeDescription *attributeDescription = object.entity.attributesByName[attributeName];
        if (attributeDescription.attributeType == NSTransformableAttributeType && value) {
            [object setValue:[self reverseTransformedValueFor:value valueTransformerName:attributeDescription.valueTransformerName] forKey:attributeName];
        } else {
            [object setValue:value forKey:attributeName];
        }
        
    }
}

- (id)reverseTransformedValueFor:(id)value valueTransformerName:(NSString *)valueTransformerName
{
    id transformedValue = nil;
    if (valueTransformerName) {
        NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:valueTransformerName];
        transformedValue = [transformer reverseTransformedValue:value];
    } else {
        transformedValue = [NSKeyedUnarchiver unarchiveObjectWithData:value];
    }
    return transformedValue;
}

- (id)transformedValueFor:(id)value valueTransformerName:(NSString *)valueTransformerName
{
    NSData *data = nil;
    if (valueTransformerName) {
        NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:valueTransformerName];
        data = (NSData *)[transformer transformedValue:value];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:value];
    }
    return data;
}

- (BOOL)shouldIgnoreKey:(NSString *)key
{
    return ([key isEqualToString:QSCloudKitTimestampKey] || [[QSCloudKitSynchronizer synchronizerMetadataKeys] containsObject:key]);
}

#pragma mark - Parent relationships

- (NSArray *)childrenRecordsForSyncedEntity:(QSSyncedEntity *)syncedEntity
{
    // Add record for this entity
    NSMutableArray *childrenRecords = [NSMutableArray array];
    [childrenRecords addObject:[self recordToUploadForSyncedEntity:syncedEntity context:self.targetContext parentSyncedEntity:nil]];
    
    NSArray *childrenRelationships = self.childrenRelationships[syncedEntity.entityType];
    for (QSChildRelationship *relationship in childrenRelationships) {
        // get child objects using parentkey
        NSString *objectID = syncedEntity.originObjectID;
        NSString *entityType = syncedEntity.entityType;
        __block NSManagedObject *originalObject;
        NSMutableArray *childrenIdentifiers = [NSMutableArray array];
        [self.targetContext performBlockAndWait:^{
            originalObject = [self managedObjectWithEntityName:entityType identifier:objectID context:self.targetContext];
            NSArray *children = [self childrenOf:originalObject withRelationship:relationship];
            for (NSManagedObject *child in children) {
                [childrenIdentifiers addObject:[self uniqueIdentifierForObject:child]];
            }
        }];
        // get their syncedEntities
        for (NSString *identifier in childrenIdentifiers) {
            QSSyncedEntity *childEntity = [self syncedEntityWithOriginObjectIdentifier:identifier];
            // add their children too
            [childrenRecords addObjectsFromArray:[self childrenRecordsForSyncedEntity:childEntity]];
        }
    }
    
    return [childrenRecords copy];
}

- (NSArray *)childrenOf:(NSManagedObject *)parent withRelationship:(QSChildRelationship *)relationship
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", relationship.childParentKey, parent];
    return [parent.managedObjectContext executeFetchRequestWithEntityName:relationship.childEntityName predicate:predicate error:nil];
}

#pragma mark - Identifier update

- (void)updateTrackingForObjectsWithPrimaryKey
{
    NSArray *entities = self.targetContext.persistentStoreCoordinator.managedObjectModel.entities;
    for (NSEntityDescription *entity in entities) {
        NSString *primaryKey = [self identifierFieldNameForEntityOfType:entity.name];
        if (primaryKey) {
            [self.targetContext performBlockAndWait:^{
                NSError *error = nil;
                NSArray *objects = [self.targetContext executeFetchRequestWithEntityName:entity.name error:&error];
                for (NSManagedObject *object in objects) {
                    NSString *objectID = [object.objectID.URIRepresentation absoluteString];
                    NSString *newIdentifier = [object valueForKey:primaryKey];
                    [self.privateContext performBlock:^{
                        QSSyncedEntity *syncedEntity = [self syncedEntityWithOriginObjectIdentifier:objectID];
                        if (syncedEntity) {
                            syncedEntity.originObjectID = newIdentifier;
                        }
                        [self savePrivateContext];
                    }];
                }
            }];
        }
    }
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
            [insertedIdentifiersAndEntityNames enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull objectIdentifier, NSString *  _Nonnull entityName, BOOL * _Nonnull stop) {
                QSSyncedEntity *entity = [self syncedEntityWithOriginObjectIdentifier:objectIdentifier];
                if (!entity) {
                    [self createSyncedEntityWithIdentifier:objectIdentifier entityName:entityName];
                }
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
                    [[NSNotificationCenter defaultCenter] postNotificationName:QSModelAdapterHasChangesNotification object:self];
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
    [self.delegate coreDataAdapterRequestsContextSave:self completion:^(NSError *error){
        if (error) {
            callBlockIfNotNil(completion, nil);
        } else {
            self.mergingImportedChanges = YES;
            DLog(@"Saved. Now importing.");
            [self.delegate coreDataAdapter:self didImportChanges:self.targetImportContext completion:^(NSError *error) {
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

- (void)saveChangesInRecords:(NSArray<CKRecord *> *)records
{
    if (records.count == 0) {
        return;
    }
    
    [self.privateContext performBlock:^{
        DLog(@"Save changes in records");
        NSMutableDictionary *queryByEntityType = [NSMutableDictionary dictionary];
        NSMutableArray *identifiers = [NSMutableArray array];
        NSMutableDictionary *entitiesByID = [NSMutableDictionary dictionary];
        for (CKRecord *record in records) {
            [identifiers addObject:record.recordID.recordName];
        }
        
        NSArray *syncedEntities = [self syncedEntitiesWithIdentifiers:identifiers];
        for (QSSyncedEntity *entity in syncedEntities) {
            entitiesByID[entity.identifier] = entity;
        }
        
        for (CKRecord *record in records) {
            QSSyncedEntity *syncedEntity = entitiesByID[record.recordID.recordName];
            if (!syncedEntity) {
                if (@available(iOS 10.0, *)) {
                    if ([record isKindOfClass:[CKShare class]]) {
                        syncedEntity = [self createSyncedEntityForShare:(CKShare *)record];
                    } else {
                        syncedEntity = [self createSyncedEntityForRecord:record];
                    }
                } else {
                    syncedEntity = [self createSyncedEntityForRecord:record];
                }
                entitiesByID[record.recordID.recordName] = syncedEntity;
            }
            
            if ([syncedEntity.state integerValue] == QSSyncedEntityStateDeleted ||
                [syncedEntity.entityType isEqualToString:@"CKShare"]) {
                
                continue;
            }
            
            QSQueryData *query = [[QSQueryData alloc] initWithIdentifier:syncedEntity.originObjectID
                                                                  record:record
                                                              entityType:syncedEntity.entityType
                                                             changedKeys:[syncedEntity.changedKeys componentsSeparatedByString:@","]
                                                             entityState:syncedEntity.state
                                                           relationships:nil];
            
            NSMutableDictionary *queries = queryByEntityType[syncedEntity.entityType];
            if (!queries) {
                queries = [NSMutableDictionary dictionary];
                queryByEntityType[syncedEntity.entityType] = queries;
            }
            
            queries[syncedEntity.originObjectID] = query;
        }
        
        [self.targetImportContext performBlockAndWait:^{
            DLog(@"Applying attribute changes in records");
            for (NSString *entityType in [queryByEntityType allKeys]) {
                NSDictionary *queries = queryByEntityType[entityType];
                NSArray *objects = [self managedObjectsWithEntityName:entityType identifiers:[queries allKeys] context:self.targetImportContext];
                for (NSManagedObject *object in objects) {
                    QSQueryData *query = queries[[self uniqueIdentifierForObject:object]];
                    [self applyAttributeChangesInRecord:query.record toManagedObject:object withSyncedState:[query.state integerValue] changedKeys:query.changedKeys];
                    NSArray *relationshipsToSave = [self relationshipsToSaveForObject:object record:query.record];
                    query.relationshipDictionary = @{@"relationshipsToSave": relationshipsToSave};
                }
            }
        }];
        
        for (CKRecord *record in records) {
            QSSyncedEntity *syncedEntity = entitiesByID[record.recordID.recordName];
            NSMutableDictionary *queries = queryByEntityType[syncedEntity.entityType];
            QSQueryData *query = queries[syncedEntity.originObjectID];
            NSArray *relationshipsToSave = query.relationshipDictionary[@"relationshipsToSave"];
            [self saveRelationshipChangesInRecord:record withNames:relationshipsToSave forEntity:syncedEntity];
            [self saveShareRelationshipForEntity:syncedEntity record:record];
            syncedEntity.updated = record[QSCloudKitTimestampKey];
            [self saveRecord:record forSyncedEntity:syncedEntity];
        }
    }];
}

- (void)deleteRecordsWithIDs:(NSArray<CKRecordID *> *)recordIDs
{
    if (recordIDs.count == 0) {
        return;
    }
    
    [self.privateContext performBlock:^{
        NSMutableArray *entities = [NSMutableArray array];
        for (CKRecordID *recordID in recordIDs) {
            NSString *entityID = recordID.recordName;
            QSSyncedEntity *syncedEntity = [self syncedEntityWithIdentifier:entityID];
            if (syncedEntity) {
                [entities addObject:syncedEntity];
            }
        }
        [self deleteSyncedEntities:entities];
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
                savedEntity.changedKeys = nil;
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
    [self.tempFileManager clearTempFiles];
}

- (nullable CKRecord *)recordForObject:(id)object
{
    NSManagedObject *managedObject = (NSManagedObject *)object;
    if (![managedObject isKindOfClass:[NSManagedObject class]] ||
        ![managedObject conformsToProtocol:@protocol(QSPrimaryKey)]) {
        return nil;
    }
    NSString *objectIdentifier = [self getThreadSafePrimaryKeyValueForManagedObject:managedObject];
    
    __block CKRecord *record = nil;
    [self.privateContext performBlockAndWait:^{
        
        QSSyncedEntity *syncedEntity = [self syncedEntityWithOriginObjectIdentifier:objectIdentifier];
        record = [self recordToUploadForSyncedEntity:syncedEntity context:self.targetContext parentSyncedEntity:nil];
    }];
    return record;
}

- (nullable CKShare *)shareForObject:(id)object NS_AVAILABLE(10.12, 10.0)
{
    NSManagedObject *managedObject = (NSManagedObject *)object;
    if (![managedObject isKindOfClass:[NSManagedObject class]] ||
        ![managedObject conformsToProtocol:@protocol(QSPrimaryKey)]) {
        return nil;
    }
    NSString *objectIdentifier = [self getThreadSafePrimaryKeyValueForManagedObject:managedObject];
    
    __block CKShare *share = nil;
    [self.privateContext performBlockAndWait:^{
        QSSyncedEntity *syncedEntity = [self syncedEntityWithOriginObjectIdentifier:objectIdentifier];
        share = [self shareForSyncedEntity:syncedEntity];
    }];
    
    return share;
}

- (void)saveShare:(nonnull CKShare *)share forObject:(id)object NS_AVAILABLE(10.12, 10.0)
{
    NSManagedObject *managedObject = (NSManagedObject *)object;
    if (![managedObject isKindOfClass:[NSManagedObject class]] ||
        ![managedObject conformsToProtocol:@protocol(QSPrimaryKey)]) {
        return;
    }
    NSString *objectIdentifier = [self getThreadSafePrimaryKeyValueForManagedObject:managedObject];
    
    [self.privateContext performBlockAndWait:^{
        QSSyncedEntity *syncedEntity = [self syncedEntityWithOriginObjectIdentifier:objectIdentifier];
        [self saveShare:share forSyncedEntity:syncedEntity];
        [self savePrivateContext];
    }];
}

- (void)deleteShareForObject:(id)object NS_AVAILABLE(10.12, 10.0)
{
    NSManagedObject *managedObject = (NSManagedObject *)object;
    if (![managedObject isKindOfClass:[NSManagedObject class]] ||
        ![managedObject conformsToProtocol:@protocol(QSPrimaryKey)]) {
        return;
    }
    NSString *objectIdentifier = [self getThreadSafePrimaryKeyValueForManagedObject:managedObject];
    
    [self.privateContext performBlockAndWait:^{
        QSSyncedEntity *syncedEntity = [self syncedEntityWithOriginObjectIdentifier:objectIdentifier];
        if (syncedEntity.share) {
            if (syncedEntity.share.record) {
                [self.privateContext deleteObject:syncedEntity.share.record];
            }
            [self.privateContext deleteObject:syncedEntity.share];
            [self savePrivateContext];
        }
    }];
}

- (nullable CKServerChangeToken *)serverChangeToken
{
    __block CKServerChangeToken *token = nil;
    [self.privateContext performBlockAndWait:^{
        NSArray *tokens = [self.privateContext executeFetchRequestWithEntityName:@"QSServerToken" predicate:nil fetchLimit:1 error:nil];
        if (tokens.count > 0) {
            QSServerToken *qsToken = [tokens firstObject];
            token = [NSKeyedUnarchiver unarchiveObjectWithData:qsToken.token];
        }
    }];
    return token;
}

- (void)saveToken:(nullable CKServerChangeToken *)token
{
    [self.privateContext performBlockAndWait:^{
        QSServerToken *qsToken = [[self.privateContext executeFetchRequestWithEntityName:@"QSServerToken" predicate:nil fetchLimit:1 error:nil] firstObject];
        if (!qsToken) {
            qsToken = [NSEntityDescription insertNewObjectForEntityForName:@"QSServerToken"
                                                    inManagedObjectContext:self.privateContext];
        }
        qsToken.token = [NSKeyedArchiver archivedDataWithRootObject:token];
        [self.privateContext save:nil];
    }];
}

- (void)deleteChangeTracking
{
    [self.stack deleteStore];
    self.privateContext = nil;
    [self clearImportContext];
    self.targetContext = nil;
}

- (NSArray<CKRecord *> *)recordsToUpdateParentRelationshipsForRoot:(id)object
{
    NSManagedObject *managedObject = (NSManagedObject *)object;
    if (![managedObject isKindOfClass:[NSManagedObject class]] ||
        ![managedObject conformsToProtocol:@protocol(QSPrimaryKey)]) {
        return nil;
    }
    
    __block NSArray *records;
    [self.privateContext performBlockAndWait:^{
        QSSyncedEntity *syncedEntity = [self syncedEntityWithOriginObjectIdentifier:[self uniqueIdentifierForObject:managedObject]];
        records = [self childrenRecordsForSyncedEntity:syncedEntity];
    }];
    return records;
}

@end
