//
//  QSRealmAdapter.m
//  Pods
//
//  Created by Manuel Entrena on 05/05/2017.
//
//

#import "QSRealmAdapter.h"
#import <Realm/Realm.h>
#import "QSSyncedEntity.h"
#import "QSRecord.h"
#import "QSSyncedEntityState.h"
#import "QSPendingRelationship.h"
#import "QSServerToken.h"
#import "QSCloudKitSynchronizer.h"
#import "QSTempFileManager.h"
#import "QSPrimaryKey.h"

void runOnMainQueue(void (^block)(void))
{
    if ([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

static NSString * const QSRealmAdapterShareRelationshipKey = @"com.syncKit.shareRelationship";

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

@interface QSRealmProvider : NSObject

@property (nonatomic, readonly, strong) RLMRealm *persistenceRealm;
@property (nonatomic, readonly, strong) RLMRealm *targetRealm;

- (instancetype)initWithPersistenceConfiguration:(RLMRealmConfiguration *)persistenceConfiguration
                             targetConfiguration:(RLMRealmConfiguration *)targetConfiguration;

@end

@implementation QSRealmProvider

- (instancetype)initWithPersistenceConfiguration:(RLMRealmConfiguration *)persistenceConfiguration
                             targetConfiguration:(RLMRealmConfiguration *)targetConfiguration
{
    self = [super init];
    if (self) {
        _persistenceRealm = [RLMRealm realmWithConfiguration:persistenceConfiguration error:nil];
        _targetRealm = [RLMRealm realmWithConfiguration:targetConfiguration error:nil];
    }
    return self;
}

@end

typedef NS_ENUM(NSInteger, QSObjectUpdateType)
{
    QSObjectUpdateTypeInsertion,
    QSObjectUpdateTypeUpdate,
    QSObjectUpdateTypeDeletion
};

@interface QSObjectUpdate : NSObject

@property (nonatomic, strong) RLMObject *object;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSString *entityType;
@property (nonatomic, assign) QSObjectUpdateType updateType;
@property (nonatomic, strong) NSArray<RLMPropertyChange *> * _Nullable changes;

- (instancetype)initWithObject:(RLMObject *)object identifier:(NSString *)identifier entityType:(NSString *)entityType updateType:(QSObjectUpdateType)updateType;
- (instancetype)initWithObject:(RLMObject *)object identifier:(NSString *)identifier entityType:(NSString *)entityType updateType:(QSObjectUpdateType)updateType changes:(NSArray<RLMPropertyChange *> *)changes;

@end

@implementation QSObjectUpdate
- (instancetype)initWithObject:(RLMObject *)object identifier:(NSString *)identifier entityType:(NSString *)entityType updateType:(QSObjectUpdateType)updateType
{
    return [self initWithObject:object identifier:identifier entityType:entityType updateType:updateType changes:nil];
}
- (instancetype)initWithObject:(RLMObject *)object identifier:(NSString *)identifier entityType:(NSString *)entityType updateType:(QSObjectUpdateType)updateType changes:(NSArray<RLMPropertyChange *> *)changes
{
    self = [super init];
    if (self) {
        self.object = object;
        self.identifier = identifier;
        self.entityType = entityType;
        self.updateType = updateType;
        self.changes = changes;
    }
    return self;
}
@end


@interface QSRealmAdapter ()

@property (nonatomic, strong, readwrite) RLMRealmConfiguration *persistenceConfiguration;
@property (nonatomic, strong, readwrite) RLMRealmConfiguration *targetConfiguration;
@property (nonatomic, strong, readwrite) CKRecordZoneID *recordZoneID;

@property (nonatomic, strong) NSMutableArray *collectionNotificationTokens;
@property (nonatomic, strong) NSMutableDictionary *objectNotificationTokens;
@property (nonatomic, strong) NSMutableArray *pendingTrackingUpdates;

@property (nonatomic, strong) QSRealmProvider *mainRealmProvider;

@property (nonatomic, strong) QSTempFileManager *tempFileManager;

@property (nonatomic, assign) BOOL hasChanges;

@property (nonatomic, strong) NSDictionary *childrenRelationships;

@end

@implementation QSRealmAdapter

- (instancetype)initWithPersistenceRealmConfiguration:(RLMRealmConfiguration *)configuration targetRealmConfiguration:(RLMRealmConfiguration *)targetRealmConfiguration recordZoneID:(CKRecordZoneID *)zoneID
{
    self = [super init];
    if (self) {
        self.persistenceConfiguration = configuration;
        self.targetConfiguration = targetRealmConfiguration;
        self.recordZoneID = zoneID;
        
        self.objectNotificationTokens = [NSMutableDictionary dictionary];
        self.collectionNotificationTokens = [NSMutableArray array];
        self.pendingTrackingUpdates = [NSMutableArray array];
        
        self.tempFileManager = [[QSTempFileManager alloc] init];
        
        runOnMainQueue(^{
            [self setup];
            [self setupChildrenRelationshipsLookup];
        });
    }
    return self;
}

- (void)dealloc
{
    [self invalidateRealmAndTokens];
}

- (void)invalidateRealmAndTokens
{
    runOnMainQueue(^{
        for (RLMNotificationToken *token in [self.objectNotificationTokens allValues]) {
            [token invalidate];
        }
        [self.objectNotificationTokens removeAllObjects];
        for (RLMNotificationToken *token in self.collectionNotificationTokens) {
            [token invalidate];
        }
        [self.collectionNotificationTokens removeAllObjects];
        
        [self.mainRealmProvider.persistenceRealm invalidate];
        self.mainRealmProvider = nil;
    });
}

+ (nonnull RLMRealmConfiguration *)defaultPersistenceConfiguration
{
    RLMRealmConfiguration *configuration = [[RLMRealmConfiguration alloc] init];
    configuration.schemaVersion = 1;
    configuration.migrationBlock = ^(RLMMigration * _Nonnull migration, uint64_t oldSchemaVersion) {
        
    };
    configuration.objectClasses = @[[QSSyncedEntity class], [QSRecord class], [QSPendingRelationship class], [QSServerToken class]];
    return configuration;
}

- (void)setup
{
    self.mainRealmProvider = [[QSRealmProvider alloc] initWithPersistenceConfiguration:self.persistenceConfiguration targetConfiguration:self.targetConfiguration];
    
    BOOL needsInitialSetup = [[QSSyncedEntity allObjectsInRealm:self.mainRealmProvider.persistenceRealm] count] == 0;
    
    __weak QSRealmAdapter *weakSelf = self;
    
    for (RLMObjectSchema *objectSchema in self.mainRealmProvider.targetRealm.schema.objectSchema) {
        Class objectClass = NSClassFromString(objectSchema.className);
        NSString *primaryKey = [objectClass primaryKey];
        RLMResults *results = [objectClass allObjectsInRealm:self.mainRealmProvider.targetRealm];
        
        //Register for insertions
        RLMNotificationToken *token = [results addNotificationBlock:^(RLMResults * _Nullable results, RLMCollectionChange * _Nullable change, NSError * _Nullable error) {
            for (NSNumber *index in change.insertions) {
                RLMObject *object = [results objectAtIndex:[index integerValue]];
                NSString *identifier = [object valueForKey:primaryKey];
                
                /* This can be called during a transaction, and it's illegal to add a notification block during a transaction,
                 * so we keep all the insertions in a list to be processed as soon as the realm finishes the current transaction
                 */
                if ([object.realm inWriteTransaction]) {
                    [self.pendingTrackingUpdates addObject:[[QSObjectUpdate alloc] initWithObject:object identifier:identifier entityType:objectSchema.className updateType:QSObjectUpdateTypeInsertion]];
                } else {
                    [self updateTrackingForInsertedObject:object withIdentifier:identifier entityName:objectSchema.className provider:self.mainRealmProvider];
                }
            }
        }];
        [self.collectionNotificationTokens addObject:token];
        
        for (RLMObject *object in results) {
            NSString *identifier = [object valueForKey:primaryKey];
            RLMNotificationToken *token = [object addNotificationBlock:^(BOOL deleted, NSArray<RLMPropertyChange *> * _Nullable changes, NSError * _Nullable error) {
                if ([self.mainRealmProvider.persistenceRealm inWriteTransaction]) {
                    [self.pendingTrackingUpdates addObject:[[QSObjectUpdate alloc] initWithObject:nil identifier:identifier entityType:objectSchema.className updateType:(deleted ? QSObjectUpdateTypeDeletion : QSObjectUpdateTypeUpdate) changes:changes]];
                } else {
                    [weakSelf updateTrackingForObjectIdentifier:identifier entityName:objectSchema.className inserted:NO deleted:deleted changes:changes realmProvider:self.mainRealmProvider];
                }
            }];
            if (needsInitialSetup) {
                [self createSyncedEntityForObjectOfType:objectSchema.className identifier:identifier inRealm:self.mainRealmProvider.persistenceRealm];
            }
            
            [self.objectNotificationTokens setObject:token forKey:identifier];
        }
    }
    
    RLMNotificationToken *token = [self.mainRealmProvider.targetRealm addNotificationBlock:^(RLMNotification  _Nonnull notification, RLMRealm * _Nonnull realm) {
        [weakSelf enqueueObjectUpdates];
    }];
    [self.collectionNotificationTokens addObject:token];
    
    [self updateHasChangesWithRealm:self.mainRealmProvider.persistenceRealm];
    if (self.hasChanges) {
        [[NSNotificationCenter defaultCenter] postNotificationName:QSModelAdapterHasChangesNotification object:self];
    }
}

- (void)setupChildrenRelationshipsLookup
{
    NSMutableDictionary *relationships = [NSMutableDictionary dictionary];
    for (RLMObjectSchema *objectSchema in self.mainRealmProvider.targetRealm.schema.objectSchema) {
        Class objectClass = NSClassFromString(objectSchema.className);
        if ([objectClass conformsToProtocol:@protocol(QSParentKey)]) {
            NSString *parentKey = [objectClass parentKey];
            RLMProperty *parentProperty;
            for (RLMProperty *property in objectSchema.properties) {
                if ([property.name isEqualToString:parentKey]) {
                    parentProperty = property;
                    break;
                }
            }

            QSChildRelationship *relationship = [[QSChildRelationship alloc] initWithParent:parentProperty.objectClassName child:objectSchema.className parentKey:parentKey];
            NSString *parentClassName = parentProperty.objectClassName;
            NSMutableArray *children = relationships[parentClassName];
            if (!children) {
                children = [NSMutableArray array];
                relationships[parentClassName] = children;
            }
            [children addObject:relationship];
        }
    }
    self.childrenRelationships = [relationships copy];
}


/*
 *  We need to track newly inserted objects, but Realm doesn't allow adding a notification block
 *  when the realm is in a write transaction (and it might be, when the notification for the collection
 *  is received). The "inWriteTransaction" property doesn't seem to be KVO compliant, so we resort to
 *  periodically checking it until the realm finishes the current write transaction and we're free to
 *  add new notification blocks.
 */
- (void)enqueueObjectUpdates
{
    if (self.pendingTrackingUpdates.count) {
        if ([self.mainRealmProvider.targetRealm inWriteTransaction]) {
            __weak QSRealmAdapter *weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf enqueueObjectUpdates];
            });
        } else {
            [self updateObjectTracking];
        }
    }
}

- (void)updateObjectTracking
{
    for (QSObjectUpdate *update in self.pendingTrackingUpdates) {
        if (update.updateType == QSObjectUpdateTypeInsertion) {
            [self updateTrackingForInsertedObject:update.object withIdentifier:update.identifier entityName:update.entityType provider:self.mainRealmProvider];
        } else {
            [self updateTrackingForObjectIdentifier:update.identifier entityName:update.entityType inserted:NO deleted:(update.updateType == QSObjectUpdateTypeDeletion) changes:update.changes realmProvider:self.mainRealmProvider];
        }
    }
    [self.pendingTrackingUpdates removeAllObjects];
}

- (void)updateTrackingForInsertedObject:(RLMObject *)object withIdentifier:(NSString *)identifier entityName:(NSString *)entityName provider:(QSRealmProvider *)provider
{
    __weak QSRealmAdapter *weakSelf = self;
    RLMNotificationToken *token = [object addNotificationBlock:^(BOOL deleted, NSArray<RLMPropertyChange *> * _Nullable changes, NSError * _Nullable error) {
        [weakSelf updateTrackingForObjectIdentifier:identifier entityName:entityName inserted:NO deleted:deleted changes:changes realmProvider:provider];
    }];
    [self.objectNotificationTokens setObject:token forKey:identifier];
    
    [self updateTrackingForObjectIdentifier:identifier entityName:entityName inserted:YES deleted:NO changes:nil realmProvider:provider];
}

- (void)updateTrackingForObjectIdentifier:(NSString *)objectIdentifier entityName:(NSString *)entityName inserted:(BOOL)inserted deleted:(BOOL)deleted changes:(NSArray<RLMPropertyChange *> *)changes realmProvider:(QSRealmProvider *)provider
{
    BOOL isNewChange = NO;
    NSString *identifier = [NSString stringWithFormat:@"%@.%@", entityName, objectIdentifier];
    QSSyncedEntity *syncedEntity = [self syncedEntityForObjectWithIdentifier:identifier inRealm:provider.persistenceRealm];
    
    if (deleted) {
        
        isNewChange = YES;
        
        if (syncedEntity) {
            [provider.persistenceRealm beginWriteTransaction];
            syncedEntity.state = @(QSSyncedEntityStateDeleted);
            [provider.persistenceRealm commitWriteTransaction];
        }
        
        RLMNotificationToken *token = [self.objectNotificationTokens objectForKey:objectIdentifier];
        if (token) {
            [self.objectNotificationTokens removeObjectForKey:objectIdentifier];
            [token invalidate];
        }
    } else if (!syncedEntity) {
        syncedEntity = [self createSyncedEntityForObjectOfType:entityName identifier:objectIdentifier inRealm:provider.persistenceRealm];
        
        if (inserted) {
            isNewChange = YES;
        }
        
    } else if (!inserted) {
        
        isNewChange = YES;

        NSMutableSet *changedKeys;
        if (syncedEntity.changedKeys) {
            changedKeys = [NSMutableSet setWithArray:[syncedEntity.changedKeys componentsSeparatedByString:@","]];
        } else {
            changedKeys = [NSMutableSet set];
        }
        
        for (RLMPropertyChange *propertyChange in changes) {
            [changedKeys addObject:propertyChange.name];
        }
        
        [provider.persistenceRealm beginWriteTransaction];
        syncedEntity.changedKeys = [[changedKeys allObjects] componentsJoinedByString:@","];
        if ([syncedEntity.state integerValue] == QSSyncedEntityStateSynced && syncedEntity.changedKeys.length) {
            syncedEntity.state = @(QSSyncedEntityStateChanged);
        } // If state was New then leave it as that
        [provider.persistenceRealm commitWriteTransaction];
    }
    
    if (!self.hasChanges && isNewChange) {
        self.hasChanges = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:QSModelAdapterHasChangesNotification object:self];
    }
}

- (QSSyncedEntity *)createSyncedEntityForObjectOfType:(NSString *)entityName identifier:(NSString *)objectIdentifier inRealm:(RLMRealm *)realm
{
    QSSyncedEntity *syncedEntity = [[QSSyncedEntity alloc] init];
    syncedEntity.identifier = [NSString stringWithFormat:@"%@.%@", entityName, objectIdentifier];
    syncedEntity.entityType = entityName;
    syncedEntity.state = @(QSSyncedEntityStateNew);
    
    [realm beginWriteTransaction];
    [realm addObject:syncedEntity];
    [realm commitWriteTransaction];
    
    return syncedEntity;
}

- (QSSyncedEntity *)createSyncedEntityForRecord:(CKRecord *)record realmProvider:(QSRealmProvider *)provider
{
    QSSyncedEntity *syncedEntity = [[QSSyncedEntity alloc] init];
    syncedEntity.identifier = record.recordID.recordName;
    syncedEntity.entityType = record.recordType;
    syncedEntity.state = @(QSSyncedEntityStateSynced);
    
    
    [provider.persistenceRealm addObject:syncedEntity];
    
    Class objectClass = NSClassFromString(record.recordType);
    NSString *primaryKey = [objectClass primaryKey];
    NSString *objectIdentifier = [self objectIdentifierForSyncedEntity:syncedEntity];
    RLMObject *object = [[objectClass alloc] initWithValue:@{primaryKey: objectIdentifier}];
    
    [provider.targetRealm addObject:object];
    
    return syncedEntity;
}

- (void)updateHasChangesWithRealm:(RLMRealm *)realm
{
    RLMResults *results = [QSSyncedEntity objectsInRealm:realm where:@"state != %@", @(QSSyncedEntityStateSynced)];
    self.hasChanges = results.count > 0;
}

- (QSSyncedEntity *)syncedEntityForObject:(RLMObject *)object inRealm:(RLMRealm *)realm
{
    Class objectClass = [object class];
    NSString *identifier = [NSString stringWithFormat:@"%@.%@", object.objectSchema.className, [object valueForKey:[objectClass primaryKey]]];
    return [self syncedEntityForObjectWithIdentifier:identifier inRealm:realm];
}

- (QSSyncedEntity *)syncedEntityForObjectWithIdentifier:(NSString *)identifier inRealm:(RLMRealm *)realm
{
    return [QSSyncedEntity objectInRealm:realm forPrimaryKey:identifier];
}

- (NSString *)objectIdentifierForSyncedEntity:(QSSyncedEntity *)syncedEntity
{
    return [syncedEntity.identifier substringFromIndex:syncedEntity.entityType.length + 1]; // entityName-objectIdentifier
}

- (void)applyChangesInRecord:(CKRecord *)record toObject:(RLMObject *)object withSyncedEntity:(QSSyncedEntity *)syncedEntity realmProvider:(QSRealmProvider *)provider
{
    if ([syncedEntity.state integerValue] == QSSyncedEntityStateChanged || [syncedEntity.state integerValue] == QSSyncedEntityStateNew) {
        if (self.mergePolicy == QSModelAdapterMergePolicyServer) {
            
            for (RLMProperty *property in object.objectSchema.properties) {
                if ([self shouldIgnoreKey:property.name]) {
                    continue;
                }
                if (property.array || property.type == RLMPropertyTypeLinkingObjects) {
                    continue;
                }
                
                [self applyChangeForProperty:property.name inRecord:record toObject:object withSyncedEntity:syncedEntity realmProvider:provider];
            }
            
        } else if (self.mergePolicy == QSModelAdapterMergePolicyClient) {
            
            NSArray *changedKeys = syncedEntity.changedKeys ? [syncedEntity.changedKeys componentsSeparatedByString:@","] : @[];
            
            for (RLMProperty *property in object.objectSchema.properties) {
                if (property.array || property.type == RLMPropertyTypeLinkingObjects) {
                    continue;
                }
                
                if (![self shouldIgnoreKey:property.name] &&
                    ![changedKeys containsObject:property.name] &&
                    [syncedEntity.state integerValue] != QSSyncedEntityStateNew) {
                    
                    [self applyChangeForProperty:property.name inRecord:record toObject:object withSyncedEntity:syncedEntity realmProvider:provider];
                }
            }
            
        } else if (self.mergePolicy == QSModelAdapterMergePolicyCustom) {
            
            NSMutableDictionary *recordChanges = [NSMutableDictionary dictionary];
            
            for (RLMProperty *property in object.objectSchema.properties) {
                if (property.array || property.type == RLMPropertyTypeLinkingObjects) {
                    continue;
                }
                
                if (![self shouldIgnoreKey:property.name] &&
                    ![record[property.name] isKindOfClass:[CKReference class]]) {
                    
                    if ([record[property.name] isKindOfClass:[CKAsset class]]) {
                        CKAsset *asset = record[property.name];
                        recordChanges[property.name] = [NSData dataWithContentsOfURL:asset.fileURL];
                    } else {
                        recordChanges[property.name] = record[property.name] ?: [NSNull null];
                    }
                }
            }
            
            if ([self.delegate respondsToSelector:@selector(realmAdapter:gotChanges:forObject:)]) {
                [self.delegate realmAdapter:self gotChanges:[recordChanges copy] forObject:object];
            }
        }
    } else {
        
        for (RLMProperty *property in object.objectSchema.properties) {
            if ([self shouldIgnoreKey:property.name]) {
                continue;
            }
            if (property.array || property.type == RLMPropertyTypeLinkingObjects) {
                continue;
            }
            
            [self applyChangeForProperty:property.name inRecord:record toObject:object withSyncedEntity:syncedEntity realmProvider:provider];
        }
    }
}

- (void)applyChangeForProperty:(NSString *)key inRecord:(CKRecord *)record toObject:(RLMObject *)object withSyncedEntity:(QSSyncedEntity *)syncedEntity realmProvider:(QSRealmProvider *)provider
{
    if ([key isEqualToString:object.objectSchema.primaryKeyProperty.name]) {
        return; // This shouldn't happen
    }
    
    id value = record[key];
                
    if ([value isKindOfClass:[CKReference class]]) {
        // Save relationship to be applied after all records have been downloaded and persisted
        // to ensure target of the relationship has already been created
        CKReference *reference = value;
        NSRange separatorRange = [reference.recordID.recordName rangeOfString:@"."];
        NSString *objectIdentifier = [reference.recordID.recordName substringFromIndex:separatorRange.location + 1];
        [self savePendingRelationshipWithName:key syncedEntity:syncedEntity targetIdentifier:objectIdentifier realm:provider.persistenceRealm];
    } else if ([value isKindOfClass:[CKAsset class]]) {
        CKAsset *asset = value;
        NSData *data = [NSData dataWithContentsOfURL:asset.fileURL];
        [object setValue:data forKey:key];
    } else {
        // If property is not a relationship, asset, or property is nil
        [object setValue:value forKey:key];
    }
}

- (void)savePendingRelationshipWithName:(NSString *)name syncedEntity:(QSSyncedEntity *)syncedEntity targetIdentifier:(NSString *)targetID realm:(RLMRealm *)realm
{
    QSPendingRelationship *pendingRelationship = [[QSPendingRelationship alloc] init];
    pendingRelationship.relationshipName = name;
    pendingRelationship.forSyncedEntity = syncedEntity;
    pendingRelationship.targetIdentifier = targetID;
    [realm addObject:pendingRelationship];
}

- (void)saveShareRelationshipForEntity:(QSSyncedEntity *)entity record:(CKRecord *)record
{
    if (record.share) {
        QSPendingRelationship *relationship = [[QSPendingRelationship alloc] init];
        relationship.relationshipName = QSRealmAdapterShareRelationshipKey;
        relationship.targetIdentifier = record.share.recordID.recordName;
        relationship.forSyncedEntity = entity;
        [entity.realm addObject:relationship];
    }
}

- (void)applyPendingRelationshipsWithRealmProvider:(QSRealmProvider *)provider
{
    RLMResults *pendingRelationships = [QSPendingRelationship allObjectsInRealm:provider.persistenceRealm];
    
    if (pendingRelationships.count == 0) {
        return;
    }
    
    [provider.persistenceRealm beginWriteTransaction];
    [provider.targetRealm beginWriteTransaction];
    
    for (QSPendingRelationship *relationship in pendingRelationships) {
        
        QSSyncedEntity *syncedEntity = relationship.forSyncedEntity;
        Class originObjectClass = NSClassFromString(syncedEntity.entityType);
        NSString *objectIdentifier = [self objectIdentifierForSyncedEntity:syncedEntity];
        RLMObject *origin = [originObjectClass objectInRealm:provider.targetRealm forPrimaryKey:objectIdentifier];
        
        if ([relationship.relationshipName isEqualToString:QSRealmAdapterShareRelationshipKey]) {
            syncedEntity.share = [self syncedEntityForObjectWithIdentifier:relationship.targetIdentifier inRealm:provider.persistenceRealm];
            [provider.persistenceRealm deleteObject:relationship];
            continue;
        }
        
        NSString *targetClassName = nil;
        for (RLMProperty *property in origin.objectSchema.properties) {
            if ([property.name isEqualToString:relationship.relationshipName]) {
                targetClassName = property.objectClassName;
                break;
            }
        }
        if (!targetClassName) {
            continue;
        }
        
        Class targetObjectClass = NSClassFromString(targetClassName);
        RLMObject *targetObject = [targetObjectClass objectInRealm:provider.targetRealm forPrimaryKey:relationship.targetIdentifier];
        
        [origin setValue:targetObject forKey:relationship.relationshipName];
        
        [provider.persistenceRealm deleteObject:relationship];
    }
    
    [provider.persistenceRealm commitWriteTransaction];
    [self commitTargetWriteTransactionWithoutNotifying];
}

- (void)saveRecord:(CKRecord *)record forSyncedEntity:(QSSyncedEntity *)syncedEntity
{
    QSRecord *qsRecord = syncedEntity.record;
    if (!qsRecord) {
        qsRecord = [[QSRecord alloc] init];
        syncedEntity.record = qsRecord;
    }
    qsRecord.encodedRecord = [self encodedRecord:record onlySystemFields:YES];
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

- (void)saveShare:(CKShare *)share forSyncedEntity:(QSSyncedEntity *)entity realmProvider:(QSRealmProvider *)provider NS_AVAILABLE(10.12, 10.0)
{
    QSRecord *qsRecord;
    QSSyncedEntity *entityForShare = entity.share;
    if (!entityForShare) {
        entityForShare = [self createSyncedEntityForShare:share realmProvider:provider];
        qsRecord = [[QSRecord alloc] init];
        
        [provider.persistenceRealm addObject:qsRecord];
        
        entityForShare.record = qsRecord;
        entity.share = entityForShare;
    } else {
        qsRecord = entityForShare.record;
    }
    
    qsRecord.encodedRecord = [self encodedRecord:share onlySystemFields:NO];
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

- (QSSyncedEntity *)createSyncedEntityForShare:(CKShare *)share realmProvider:(QSRealmProvider *)provider NS_AVAILABLE(10.12, 10.0)
{
    QSSyncedEntity *entityForShare = [[QSSyncedEntity alloc] init];
    entityForShare.entityType = @"CKShare";
    entityForShare.identifier = share.recordID.recordName;
    entityForShare.updated = [NSDate date];
    entityForShare.state = @(QSSyncedEntityStateSynced);
    
    [provider.persistenceRealm addObject:entityForShare];
    
    return entityForShare;
}

- (BOOL)shouldIgnoreKey:(NSString *)key
{
    return [[QSCloudKitSynchronizer synchronizerMetadataKeys] containsObject:key];
}

- (CKRecord *)recordToUploadForSyncedEntity:(QSSyncedEntity *)syncedEntity realmProvider:(QSRealmProvider *)realmProvider parentSyncedEntity:(QSSyncedEntity **)parentSyncedEntity
{
    if (!syncedEntity) {
        return nil;
    }
    
    CKRecord *record = [self recordForSyncedEntity:syncedEntity];
    if (!record) {
        record = [[CKRecord alloc] initWithRecordType:syncedEntity.entityType recordID:[[CKRecordID alloc] initWithRecordName:syncedEntity.identifier zoneID:self.recordZoneID]];
    }
    
    Class objectClass = NSClassFromString(syncedEntity.entityType);
    NSString *objectIdentifier = [self objectIdentifierForSyncedEntity:syncedEntity];
    RLMObject *object = [objectClass objectInRealm:realmProvider.targetRealm forPrimaryKey:objectIdentifier];
    QSSyncedEntityState entityState = [syncedEntity.state integerValue];
    NSArray *changedKeys = [(syncedEntity.changedKeys ?: @"") componentsSeparatedByString:@","];
    
    NSString *parentKey = nil;
    if ([objectClass conformsToProtocol:@protocol(QSParentKey)]) {
        parentKey = [objectClass parentKey];
    }

    RLMObject *parent = nil;
    for (RLMProperty *property in object.objectSchema.properties) {
        if (property.type == RLMPropertyTypeObject &&
            (entityState == QSSyncedEntityStateNew || [changedKeys containsObject:property.name])) {
            RLMObject *target = [object valueForKey:property.name];
            if (target) {
                NSString *targetIdentifier = [target valueForKey:[[target class] primaryKey]];
                NSString *referenceIdentifier = [NSString stringWithFormat:@"%@.%@", property.objectClassName, targetIdentifier];
                
                CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName:referenceIdentifier zoneID:self.recordZoneID];
                // if we set the parent we must make the action .deleteSelf, otherwise we get errors if we ever try to delete the parent record
                CKReferenceAction action = [parentKey isEqualToString:property.name] ? CKReferenceActionDeleteSelf : CKReferenceActionNone;
                CKReference *recordReference = [[CKReference alloc] initWithRecordID:recordID action:action];
                record[property.name] = recordReference;
                if ([parentKey isEqualToString:property.name]) {
                    parent = target;
                }
            }
        } else if (!property.array &&
                   property.type != RLMPropertyTypeLinkingObjects &&
                   ![property.name isEqualToString:[objectClass primaryKey]] &&
                   (entityState == QSSyncedEntityStateNew || [changedKeys containsObject:property.name])) {
            
            id value = [object valueForKey:property.name];
            if (property.type == RLMPropertyTypeData && value && !self.forceDataTypeInsteadOfAsset) {
                NSURL *fileURL = [self.tempFileManager storeData:(NSData *)value];
                CKAsset *asset = [[CKAsset alloc] initWithFileURL:fileURL];
                record[property.name] = asset;
            } else {
                record[property.name] = value;
            }
        }
    }
    
    if (parentKey && (entityState == QSSyncedEntityStateNew || [changedKeys containsObject:parentKey])) {
        CKReference *reference = record[parentKey];
        if (reference.recordID) {
            // For the parent reference we have to use action .none though, even if we must use .deleteSelf for the attribute (see ^)
            record.parent = [[CKReference alloc] initWithRecordID:reference.recordID action:CKReferenceActionNone];
            if (parent && parentSyncedEntity) {
                *parentSyncedEntity = [self syncedEntityForObject:parent inRealm:realmProvider.persistenceRealm];
            }
        }
    }

    
    return record;
}

- (NSArray *)recordsToUploadWithState:(QSSyncedEntityState)state limit:(NSInteger)limit realmProvider:(QSRealmProvider *)realmProvider
{
    RLMResults<QSSyncedEntity *> *results = [QSSyncedEntity objectsInRealm:realmProvider.persistenceRealm where:@"state == %@", @(state)];
    NSMutableArray *resultArray = [NSMutableArray array];
    NSMutableSet *includedEntityIDs = [NSMutableSet set];
    
    for (QSSyncedEntity *syncedEntity in results) {
        if (resultArray.count > limit) {
            break;
        }
        
        QSSyncedEntity *entity = syncedEntity;
        while (entity != nil && [entity.state integerValue] == state && ![includedEntityIDs containsObject:entity.identifier]) {
            QSSyncedEntity *parentEntity = nil;
            CKRecord *record = [self recordToUploadForSyncedEntity:entity realmProvider:realmProvider parentSyncedEntity:&parentEntity];
            [resultArray addObject:record];
            [includedEntityIDs addObject:entity.identifier];
            entity = parentEntity;
        }
    }
    
    return [resultArray copy];
}

- (QSSyncedEntityState)nextStateToSyncAfter:(QSSyncedEntityState)state
{
    return state + 1;
}

- (void)commitTargetWriteTransactionWithoutNotifying
{
    NSArray *tokens = [self.objectNotificationTokens allValues];
    [self.mainRealmProvider.targetRealm commitWriteTransactionWithoutNotifying:tokens error:nil];
}

#pragma mark - Parent relationships

- (NSArray *)childrenRecordsForSyncedEntity:(QSSyncedEntity *)syncedEntity
{
    // Add record for this entity
    NSMutableArray *childrenRecords = [NSMutableArray array];
    [childrenRecords addObject:[self recordToUploadForSyncedEntity:syncedEntity realmProvider:self.mainRealmProvider parentSyncedEntity:nil]];
    
    NSArray *childrenRelationships = self.childrenRelationships[syncedEntity.entityType];
    for (QSChildRelationship *relationship in childrenRelationships) {
        // get child objects using parentkey
        Class objectClass = NSClassFromString(syncedEntity.entityType);
        NSString *objectID = [self objectIdentifierForSyncedEntity:syncedEntity];
        RLMObject *object = [objectClass objectInRealm:self.mainRealmProvider.targetRealm forPrimaryKey:objectID];
        RLMResults *children = [self childrenOf:object withRelationship:relationship];
        
        // get their syncedEntities
        for (RLMObject *child in children) {
            QSSyncedEntity *childEntity = [self syncedEntityForObject:child inRealm:self.mainRealmProvider.persistenceRealm];
            // add their children too
            [childrenRecords addObjectsFromArray:[self childrenRecordsForSyncedEntity:childEntity]];
        }
    }
    
    return [childrenRecords copy];
}

- (RLMResults *)childrenOf:(RLMObject *)parent withRelationship:(QSChildRelationship *)relationship
{
    Class objectClass = NSClassFromString(relationship.childEntityName);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", relationship.childParentKey, parent];
    return [objectClass objectsInRealm:parent.realm withPredicate:predicate];
}

#pragma mark - QSModelAdapter


- (void)prepareForImport
{
}

- (void)saveChangesInRecords:(NSArray<CKRecord *> *)records
{
    if (records.count == 0) {
        return;
    }
    
    runOnMainQueue(^{
        [self.mainRealmProvider.persistenceRealm beginWriteTransaction];
        [self.mainRealmProvider.targetRealm beginWriteTransaction];
        for (CKRecord *record in records) {
            QSSyncedEntity *syncedEntity = [self syncedEntityForObjectWithIdentifier:record.recordID.recordName inRealm:self.mainRealmProvider.persistenceRealm];
            
            if (!syncedEntity) {
                if (@available(iOS 10.0, *)) {
                    if ([record isKindOfClass:[CKShare class]]) {
                        syncedEntity = [self createSyncedEntityForShare:(CKShare *)record realmProvider:self.mainRealmProvider];
                    } else {
                        syncedEntity = [self createSyncedEntityForRecord:record realmProvider:self.mainRealmProvider];
                    }
                } else {
                    syncedEntity = [self createSyncedEntityForRecord:record realmProvider:self.mainRealmProvider];
                }
            }
            
            if ([syncedEntity.state integerValue] != QSSyncedEntityStateDeleted &&
                ![syncedEntity.entityType isEqualToString:@"CKShare"]) {
                
                Class objectClass = NSClassFromString(record.recordType);
                NSString *objectIdentifier = [self objectIdentifierForSyncedEntity:syncedEntity];
                RLMObject *object = [objectClass objectInRealm:self.mainRealmProvider.targetRealm forPrimaryKey:objectIdentifier];
                
                [self applyChangesInRecord:record toObject:object withSyncedEntity:syncedEntity realmProvider:self.mainRealmProvider];
                [self saveShareRelationshipForEntity:syncedEntity record:record];
            }
            
            [self saveRecord:record forSyncedEntity:syncedEntity];
        }
        // Order is important here. Notifications might be delivered after targetRealm is saved and
        // it's convenient if the persistenceRealm is not in a write transaction
        [self.mainRealmProvider.persistenceRealm commitWriteTransaction];
        [self commitTargetWriteTransactionWithoutNotifying];
    });
}

- (void)deleteRecordsWithIDs:(NSArray<CKRecordID *> *)recordIDs
{
    if (recordIDs.count == 0) {
        return;
    }
    
    runOnMainQueue(^{
        [self.mainRealmProvider.persistenceRealm beginWriteTransaction];
        [self.mainRealmProvider.targetRealm beginWriteTransaction];
        for (CKRecordID *recordID in recordIDs) {
            QSSyncedEntity *syncedEntity = [self syncedEntityForObjectWithIdentifier:recordID.recordName inRealm:self.mainRealmProvider.persistenceRealm];
            if (syncedEntity) {
                
                if (![syncedEntity.entityType isEqualToString:@"CKShare"]) {
                    Class objectClass = NSClassFromString(syncedEntity.entityType);
                    NSString *objectIdentifier = [self objectIdentifierForSyncedEntity:syncedEntity];
                    RLMObject *object = [objectClass objectInRealm:self.mainRealmProvider.targetRealm forPrimaryKey:objectIdentifier];
                    
                    if (object) {
                        RLMNotificationToken *token = [self.objectNotificationTokens objectForKey:objectIdentifier];
                        if (token) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.objectNotificationTokens removeObjectForKey:objectIdentifier];
                                [token invalidate];
                            });
                        }
                        
                        [self.mainRealmProvider.targetRealm deleteObject:object];
                    }
                }
                
                [self.mainRealmProvider.persistenceRealm deleteObject:syncedEntity];
            }
        }
        [self.mainRealmProvider.persistenceRealm commitWriteTransaction];
        [self commitTargetWriteTransactionWithoutNotifying];
    });
}


- (void)persistImportedChangesWithCompletion:(void(^)(NSError *error))completion
{
    //Apply pending relationships
    runOnMainQueue(^{
        [self applyPendingRelationshipsWithRealmProvider:self.mainRealmProvider];
    });
    
    completion(nil);
}


- (NSArray *)recordsToUploadWithLimit:(NSInteger)limit
{
    __block NSArray *recordsArray = @[];
    runOnMainQueue(^{
        NSInteger recordLimit = limit;
        QSSyncedEntityState uploadingState = QSSyncedEntityStateNew;
        
        if (recordLimit == 0) { recordLimit = NSIntegerMax; }
        
        NSInteger innerLimit = recordLimit;
        while (recordsArray.count < recordLimit && uploadingState < QSSyncedEntityStateDeleted) {
            recordsArray = [recordsArray arrayByAddingObjectsFromArray:[self recordsToUploadWithState:uploadingState limit:innerLimit realmProvider:self.mainRealmProvider]];
            uploadingState = [self nextStateToSyncAfter:uploadingState];
            innerLimit = recordLimit - recordsArray.count;
        }
    });
    
    return recordsArray;
}


- (void)didUploadRecords:(NSArray *)savedRecords
{
    runOnMainQueue(^{
        [self.mainRealmProvider.persistenceRealm beginWriteTransaction];
        for (CKRecord *record in savedRecords) {
            QSSyncedEntity *syncedEntity = [QSSyncedEntity objectInRealm:self.mainRealmProvider.persistenceRealm forPrimaryKey:record.recordID.recordName];
            if (syncedEntity) {
                syncedEntity.state = @(QSSyncedEntityStateSynced);
                syncedEntity.changedKeys = nil;
                [self saveRecord:record forSyncedEntity:syncedEntity];
            }
        }
        [self.mainRealmProvider.persistenceRealm commitWriteTransaction];
    });
}


- (NSArray *)recordIDsMarkedForDeletionWithLimit:(NSInteger)limit
{
    NSMutableArray *recordIDs = [NSMutableArray array];
    runOnMainQueue(^{
        RLMResults<QSSyncedEntity *> *deletedEntities = [QSSyncedEntity objectsInRealm:self.mainRealmProvider.persistenceRealm where:@"state == %@", @(QSSyncedEntityStateDeleted)];
        
        for (QSSyncedEntity *syncedEntity in deletedEntities) {
            if (recordIDs.count > limit) {
                break;
            }
            
            [recordIDs addObject:[[CKRecordID alloc] initWithRecordName:syncedEntity.identifier zoneID:self.recordZoneID]];
        }
    });
    
    return [recordIDs copy];
}


- (void)didDeleteRecordIDs:(NSArray *)deletedRecordIDs
{
    runOnMainQueue(^{
        [self.mainRealmProvider.persistenceRealm beginWriteTransaction];
        for (CKRecordID *recordID in deletedRecordIDs) {
            
            QSSyncedEntity *syncedEntity = [QSSyncedEntity objectInRealm:self.mainRealmProvider.persistenceRealm forPrimaryKey:recordID.recordName];
            if (syncedEntity) {
                [self.mainRealmProvider.persistenceRealm deleteObject:syncedEntity];
            }
        }
        [self.mainRealmProvider.persistenceRealm commitWriteTransaction];
    });
}


- (BOOL)hasRecordID:(CKRecordID *)recordID
{
    __block BOOL hasRecord = false;
    runOnMainQueue(^{
        QSSyncedEntity *syncedEntity = [QSSyncedEntity objectInRealm:self.mainRealmProvider.persistenceRealm forPrimaryKey:recordID.recordName];
        hasRecord = syncedEntity != nil;
    });
    return hasRecord;
}


- (void)didFinishImportWithError:(NSError *)error
{
    [self.tempFileManager clearTempFiles];
    runOnMainQueue(^{
        [self updateHasChangesWithRealm:self.mainRealmProvider.persistenceRealm];
    });
}

- (nullable CKRecord *)recordForObject:(id)object
{
    RLMObject *realmObject = (RLMObject *)object;
    if ([realmObject isKindOfClass:[RLMObject class]] == NO) {
        return nil;
    }
    
    __block CKRecord *record = nil;
    
    runOnMainQueue(^{
        QSSyncedEntity *syncedEntity = [self syncedEntityForObject:realmObject inRealm:self.mainRealmProvider.persistenceRealm];
        record = [self recordToUploadForSyncedEntity:syncedEntity realmProvider:self.mainRealmProvider parentSyncedEntity:nil];
    });
    
    return record;
}

- (nullable CKShare *)shareForObject:(id)object
{
    RLMObject *realmObject = (RLMObject *)object;
    if ([realmObject isKindOfClass:[RLMObject class]] == NO) {
        return nil;
    }
    
    __block CKShare *share = nil;
    
    runOnMainQueue(^{
        QSSyncedEntity *syncedEntity = [self syncedEntityForObject:realmObject inRealm:self.mainRealmProvider.persistenceRealm];
        share = [self shareForSyncedEntity:syncedEntity];
    });
    
    return share;
}

- (void)saveShare:(nonnull CKShare *)share forObject:(id)object
{
    RLMObject *realmObject = (RLMObject *)object;
    if ([realmObject isKindOfClass:[RLMObject class]] == NO) {
        return;
    }
    
    runOnMainQueue(^{
        QSSyncedEntity *syncedEntity = [self syncedEntityForObject:realmObject inRealm:self.mainRealmProvider.persistenceRealm];
        
        [self.mainRealmProvider.persistenceRealm beginWriteTransaction];
        [self saveShare:share forSyncedEntity:syncedEntity realmProvider:self.mainRealmProvider];
        [self.mainRealmProvider.persistenceRealm commitWriteTransaction];
    });
}

- (void)deleteShareForObject:(id)object
{
    RLMObject *realmObject = (RLMObject *)object;
    if ([realmObject isKindOfClass:[RLMObject class]] == NO) {
        return;
    }
    
    runOnMainQueue(^{
        QSSyncedEntity *syncedEntity = [self syncedEntityForObject:realmObject inRealm:self.mainRealmProvider.persistenceRealm];
        QSSyncedEntity *shareEntity = syncedEntity.share;
        [self.mainRealmProvider.persistenceRealm beginWriteTransaction];
        syncedEntity.share = nil;
        if (shareEntity) {
            if (shareEntity.record) {
                [self.mainRealmProvider.persistenceRealm deleteObject:shareEntity.record];
            }
            [self.mainRealmProvider.persistenceRealm deleteObject:shareEntity];
        }
        [self.mainRealmProvider.persistenceRealm commitWriteTransaction];
    });
}

- (void)deleteChangeTracking
{
    [self invalidateRealmAndTokens];
    NSFileManager *manager = [NSFileManager defaultManager];
    RLMRealmConfiguration *config = self.persistenceConfiguration;
    NSArray<NSURL *> *realmFileURLs = @[
                                        config.fileURL,
                                        [config.fileURL URLByAppendingPathExtension:@"lock"],
                                        [config.fileURL URLByAppendingPathExtension:@"note"],
                                        [config.fileURL URLByAppendingPathExtension:@"management"]
                                        ];
    for (NSURL *URL in realmFileURLs) {
        NSError *error = nil;
        [manager removeItemAtURL:URL error:&error];
        if (error) {
            // handle error
        }
    }
}

- (nullable CKServerChangeToken *)serverChangeToken
{
    __block CKServerChangeToken *token = nil;
    runOnMainQueue(^{
        QSServerToken *serverToken = [[QSServerToken allObjectsInRealm:self.mainRealmProvider.persistenceRealm] firstObject];
        if (serverToken.token) {
            token = [NSKeyedUnarchiver unarchiveObjectWithData:serverToken.token];
        }
    });
    return token;
}

- (void)saveToken:(nullable CKServerChangeToken *)token
{
    runOnMainQueue(^{
        QSServerToken *serverToken = [[QSServerToken allObjectsInRealm:self.mainRealmProvider.persistenceRealm] firstObject];
        
        [self.mainRealmProvider.persistenceRealm beginWriteTransaction];
        
        if (!serverToken) {
            serverToken = [[QSServerToken alloc] init];
            
            [self.mainRealmProvider.persistenceRealm addObject:serverToken];
        }
        serverToken.token = [NSKeyedArchiver archivedDataWithRootObject:token];
        
        [self.mainRealmProvider.persistenceRealm commitWriteTransaction];
    });
}

- (NSArray<CKRecord *> *)recordsToUpdateParentRelationshipsForRoot:(id)object
{
    RLMObject *realmObject = (RLMObject *)object;
    if ([realmObject isKindOfClass:[RLMObject class]] == NO) {
        return nil;
    }
    
    __block NSArray *records;
    runOnMainQueue(^{
        QSSyncedEntity *syncedEntity = [self syncedEntityForObject:realmObject inRealm:self.mainRealmProvider.persistenceRealm];
        records = [self childrenRecordsForSyncedEntity:syncedEntity];
    });
    return records;
}


@end
