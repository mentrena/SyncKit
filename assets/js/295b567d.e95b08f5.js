(window.webpackJsonp=window.webpackJsonp||[]).push([[16],{132:function(e,t,n){"use strict";n.d(t,"a",(function(){return p})),n.d(t,"b",(function(){return m}));var r=n(0),a=n.n(r);function i(e,t,n){return t in e?Object.defineProperty(e,t,{value:n,enumerable:!0,configurable:!0,writable:!0}):e[t]=n,e}function o(e,t){var n=Object.keys(e);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);t&&(r=r.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),n.push.apply(n,r)}return n}function l(e){for(var t=1;t<arguments.length;t++){var n=null!=arguments[t]?arguments[t]:{};t%2?o(Object(n),!0).forEach((function(t){i(e,t,n[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(n)):o(Object(n)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(n,t))}))}return e}function c(e,t){if(null==e)return{};var n,r,a=function(e,t){if(null==e)return{};var n,r,a={},i=Object.keys(e);for(r=0;r<i.length;r++)n=i[r],t.indexOf(n)>=0||(a[n]=e[n]);return a}(e,t);if(Object.getOwnPropertySymbols){var i=Object.getOwnPropertySymbols(e);for(r=0;r<i.length;r++)n=i[r],t.indexOf(n)>=0||Object.prototype.propertyIsEnumerable.call(e,n)&&(a[n]=e[n])}return a}var d=a.a.createContext({}),s=function(e){var t=a.a.useContext(d),n=t;return e&&(n="function"==typeof e?e(t):l(l({},t),e)),n},p=function(e){var t=s(e.components);return a.a.createElement(d.Provider,{value:t},e.children)},g={inlineCode:"code",wrapper:function(e){var t=e.children;return a.a.createElement(a.a.Fragment,{},t)}},u=a.a.forwardRef((function(e,t){var n=e.components,r=e.mdxType,i=e.originalType,o=e.parentName,d=c(e,["components","mdxType","originalType","parentName"]),p=s(n),u=r,m=p["".concat(o,".").concat(u)]||p[u]||g[u]||i;return n?a.a.createElement(m,l(l({ref:t},d),{},{components:n})):a.a.createElement(m,l({ref:t},d))}));function m(e,t){var n=arguments,r=t&&t.mdxType;if("string"==typeof e||r){var i=n.length,o=new Array(i);o[0]=u;var l={};for(var c in t)hasOwnProperty.call(t,c)&&(l[c]=t[c]);l.originalType=e,l.mdxType="string"==typeof e?e:r,o[1]=l;for(var d=2;d<i;d++)o[d]=n[d];return a.a.createElement.apply(null,o)}return a.a.createElement.apply(null,n)}u.displayName="MDXCreateElement"},86:function(e,t,n){"use strict";n.r(t),n.d(t,"frontMatter",(function(){return o})),n.d(t,"metadata",(function(){return l})),n.d(t,"toc",(function(){return c})),n.d(t,"default",(function(){return s}));var r=n(3),a=n(7),i=(n(0),n(132)),o={id:"migration",title:"Migrating from SyncKit 0.3.0"},l={unversionedId:"migration",id:"migration",isDocsHomePage:!1,title:"Migrating from SyncKit 0.3.0",description:"If you were using SyncKit before 0.3.0 and you want to adopt the QSPrimaryKey protocol this page offers some guidance. There are different methods that you could adopt based on your app.",source:"@site/docs/migration.md",slug:"/migration",permalink:"/SyncKit/migration",editUrl:"https://github.com/facebook/docusaurus/edit/master/website/docs/migration.md",version:"current",sidebar:"docs",previous:{title:"SyncKit for Core Data",permalink:"/SyncKit/coredata"},next:{title:"SyncKit for Realm",permalink:"/SyncKit/realm"}},c=[{value:"Existing primary key",id:"existing-primary-key",children:[]},{value:"Adding primary key field in your model",id:"adding-primary-key-field-in-your-model",children:[]},{value:"Discarding current SyncKit tracking data",id:"discarding-current-synckit-tracking-data",children:[]}],d={toc:c};function s(e){var t=e.components,n=Object(a.a)(e,["components"]);return Object(i.b)("wrapper",Object(r.a)({},d,n,{components:t,mdxType:"MDXLayout"}),Object(i.b)("p",null,"If you were using SyncKit before 0.3.0 and you want to adopt the ",Object(i.b)("inlineCode",{parentName:"p"},"QSPrimaryKey")," protocol this page offers some guidance. There are different methods that you could adopt based on your app."),Object(i.b)("h2",{id:"existing-primary-key"},"Existing primary key"),Object(i.b)("p",null,"If your objects already had a populated primary key: Make them implement ",Object(i.b)("inlineCode",{parentName:"p"},"QSPrimaryKey")," and call ",Object(i.b)("inlineCode",{parentName:"p"},"updateTrackingForObjectsWithPrimaryKey")," on the change manager to make it update its object tracking data so it uses the primary key."),Object(i.b)("ol",null,Object(i.b)("li",{parentName:"ol"},"Add the ",Object(i.b)("inlineCode",{parentName:"li"},"+ (nonnull NSString *)primaryKey")," to your classes."),Object(i.b)("li",{parentName:"ol"},"Update tracking data:")),Object(i.b)("pre",null,Object(i.b)("code",{parentName:"pre",className:"language-objc"},"...\n    // After launching your app, maybe in didFinishLaunchingWithOptions\n    [self.synchronizer.changeManager updateTrackingForObjectsWithPrimaryKey];\n...\n")),Object(i.b)("ol",{start:3},Object(i.b)("li",{parentName:"ol"},"Now you can use SyncKit.")),Object(i.b)("h2",{id:"adding-primary-key-field-in-your-model"},"Adding primary key field in your model"),Object(i.b)("p",null,"If you need to change your model to add a primary key then this will require a migration, which would break all the tracking data in SyncKit. To avoid that you can use ",Object(i.b)("inlineCode",{parentName:"p"},"QSEntityIdentifierUpdateMigrationPolicy")," as the policy in your mapping model, then call ",Object(i.b)("inlineCode",{parentName:"p"},"[QSCloudKitSynchronizer updateIdentifierMigrationPolicy];")," before starting the migration."),Object(i.b)("ol",null,Object(i.b)("li",{parentName:"ol"},"Update your CoreData model and add the required field to those model objects that might need one."),Object(i.b)("li",{parentName:"ol"},"Create a Core Data mapping model and add entity mappings for you entities."),Object(i.b)("li",{parentName:"ol"},"In your mapping model, specify ",Object(i.b)("inlineCode",{parentName:"li"},"QSEntityIdentifierUpdateMigrationPolicy")," as the Custom Policy. This policy will assign a primary key value to each object being migrated."),Object(i.b)("li",{parentName:"ol"},"When you create your Core Data stack, check if you need to perform a migration.\nSample code:")),Object(i.b)("pre",null,Object(i.b)("code",{parentName:"pre",className:"language-objc"},"- (MigrationNeededEnum)isMigrationNecessaryForStore:(NSString *)storePath\n{\n    if (![[NSFileManager defaultManager] fileExistsAtPath:self.storePath]) {\n        return NO;\n    }\n    \n    NSError *error = nil;\n    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType\n                                                                                              URL:[NSURL fileURLWithPath:storePath]\n                                                                                          options:@{NSInferMappingModelAutomaticallyOption: @YES,                                  NSMigratePersistentStoresAutomaticallyOption: @YES}\n                                                                                            error:&error];\n\n    NSManagedObjectModel *destinationModel = self.coordinator.managedObjectModel;\n    if ([destinationModel isConfiguration:nil compatibleWithStoreMetadata:sourceMetadata]) {\n        return MigrationOptionNoMigration;\n    }\n    \n    NSManagedObjectModel *sourceModel = [NSManagedObjectModel mergedModelFromBundles:@[[NSBundle mainBundle]] forStoreMetadata:sourceMetadata];\n    \n    if ([NSMappingModel inferredMappingModelForSourceModel:sourceModel destinationModel:destinationModel error:&error]) {\n        return MigrationOptionLightweightMigration;\n    }\n    \n    return MigrationOptionCustomMigration;\n}\n")),Object(i.b)("ol",{start:5},Object(i.b)("li",{parentName:"ol"},"Perform migration. Sample code:")),Object(i.b)("pre",null,Object(i.b)("code",{parentName:"pre",className:"language-objc"},'- (void)performBackgroundManagedMigrationForStore:(NSString *)sourceStore\n{\n    //Show UI\n    // Show some modal screen with some UIActivityIndicatorView or similar\n    \n    // Determine if this migration is being run to adopt primary keys, maybe checking [NSManagedObjectModel versionIdentifiers] if you\'ve been setting those on your model\n    if (useSyncKitMigrationPolity) {\n        [QSCloudKitSynchronizer updateIdentifierMigrationPolicy];\n    }\n    \n    // Perform migration in the background, so it doesn\'t freeze the UI.\n    // This way progress can be shown to the user\n    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{\n        BOOL done = [self migrateStore:sourceStore];\n        if(done) {\n            dispatch_async(dispatch_get_main_queue(), ^{\n                if (useSyncKitMigrationPolity) {\n                    [QSEntityIdentifierUpdateMigrationPolicy setCoreDataStack:nil];\n                }\n                \n                // Dismiss UI\n                // Load your persistent store\n                [self loadStore];\n            });\n        }\n    });\n}\n\n- (BOOL)migrateStore:(NSString *)sourceStore\n{\n    BOOL success = NO;\n    NSError *error = nil;\n    \n    // STEP 1 - Gather the Source, Destination and Mapping Model\n    NSURL *storeURL = [NSURL fileURLWithPath:sourceStore];\n    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:storeURL options:nil error:&error];\n    NSManagedObjectModel *sourceModel = [NSManagedObjectModel mergedModelFromBundles:nil forStoreMetadata:sourceMetadata];\n    NSManagedObjectModel *destinationModel = self.model;\n    NSMappingModel *mappingModel = [NSMappingModel mappingModelFromBundles:nil forSourceModel:sourceModel destinationModel:destinationModel];\n    \n    // STEP 2 - Perform migration, assuming the mapping model isn\'t null\n    if (mappingModel) {\n        NSError *error = nil;\n        NSMigrationManager *migrationManager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel destinationModel:destinationModel];\n        [migrationManager addObserver:self forKeyPath:@"migrationProgress" options:NSKeyValueObservingOptionNew context:NULL];\n        \n        NSString *destinationStorePath = [[self applicationStoresPath] stringByAppendingPathComponent:@"Temp.sqlite"];\n        \n        success = [migrationManager migrateStoreFromURL:storeURL\n                                                   type:NSSQLiteStoreType\n                                                options:nil\n                                       withMappingModel:mappingModel\n                                       toDestinationURL:[NSURL fileURLWithPath:destinationStorePath]\n                                        destinationType:NSSQLiteStoreType\n                                     destinationOptions:nil\n                                                  error:&error];\n        \n        [migrationManager removeObserver:self forKeyPath:@"migrationProgress"];\n        \n        if (success) {\n            // STEP 3 - Replace the old store files with the new migrated store files\n            [self replaceStore:sourceStore withStore:destinationStorePath];\n        }\n        else {\n            NSLog(@"FAILED MIGRATION: %@",error);\n        }\n    }\n    else {\n        NSLog(@"FAILED MIGRATION: Mapping Model is null");\n    }\n    return YES; // indicates migration has finished, regardless of outcome\n}\n\n- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context\n{\n    if ([object isKindOfClass:[NSMigrationManager class]]) {\n        CGFloat progress = [(NSMigrationManager *)object migrationProgress];\n        dispatch_async(dispatch_get_main_queue(), ^{\n            // Update progress indicator UI\n        });\n    }\n}\n\n- (BOOL)replaceStore:(NSString *)old withStore:(NSString *)newPath {\n    \n    BOOL success = NO;\n    NSError *error = nil;\n    \n    if ([[NSFileManager defaultManager] fileExistsAtPath:old]) {\n        [[NSFileManager defaultManager] removeItemAtPath:old error:&error];\n        \n        NSString *walPath = [old stringByAppendingString:@"-wal"];\n        if ([[NSFileManager defaultManager] fileExistsAtPath:walPath]) {\n            [[NSFileManager defaultManager] removeItemAtPath:walPath error:&error];\n        }\n        NSString *shmPath = [old stringByAppendingString:@"-shm"];\n        if ([[NSFileManager defaultManager] fileExistsAtPath:shmPath]) {\n            [[NSFileManager defaultManager] removeItemAtPath:shmPath error:&error];\n        }\n        \n        error = nil;\n        if ([[NSFileManager defaultManager] moveItemAtPath:newPath toPath:old error:&error]) {\n            NSString *newWalPath = [newPath stringByAppendingString:@"-wal"];\n            [[NSFileManager defaultManager] moveItemAtPath:newWalPath toPath:walPath error:&error];\n            NSString *newShmPath = [newPath stringByAppendingString:@"-shm"];\n            [[NSFileManager defaultManager] moveItemAtPath:newShmPath toPath:shmPath error:&error];\n            success = YES;\n        }\n    }\n    \n    return success;\n}\n')),Object(i.b)("ol",{start:6},Object(i.b)("li",{parentName:"ol"},"You can now create your ",Object(i.b)("inlineCode",{parentName:"li"},"QSCloudKitSynchronizer")," and use it to sync.")),Object(i.b)("h2",{id:"discarding-current-synckit-tracking-data"},"Discarding current SyncKit tracking data"),Object(i.b)("p",null,"A less optimal, though easier option would be discarding all your existing data when the app performs a migration to add primary key fields, then synchronizing with an empty NSPersistentStore to restore using data currently on iCloud."),Object(i.b)("ol",null,Object(i.b)("li",{parentName:"ol"},"Discard all SyncKit data:")),Object(i.b)("pre",null,Object(i.b)("code",{parentName:"pre",className:"language-objc"},"[self.synchronizer eraseLocal];\n")),Object(i.b)("p",null,"or, alternatively, delete everything in ",Object(i.b)("inlineCode",{parentName:"p"},"[QSCloudKitSynchronizer storePath]")),Object(i.b)("ol",{start:2},Object(i.b)("li",{parentName:"ol"},"Delete your store file."),Object(i.b)("li",{parentName:"ol"},"Create a new Core Data stack."),Object(i.b)("li",{parentName:"ol"},"Create a new QSCloudKitSynchronizer."),Object(i.b)("li",{parentName:"ol"},"Sync. This will download all the data in iCloud to the new, empty store, so at the end of this the local stack will be a copy of the data on iCloud.")))}s.isMDXComponent=!0}}]);