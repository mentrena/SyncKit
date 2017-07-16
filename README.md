# SyncKit

[![CI Status](http://img.shields.io/travis/mentrena/SyncKit.svg?style=flat)](https://travis-ci.org/mentrena/SyncKit)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Version](https://img.shields.io/cocoapods/v/SyncKit.svg?style=flat)](http://cocoapods.org/pods/SyncKit)
[![License](https://img.shields.io/cocoapods/l/SyncKit.svg?style=flat)](http://cocoapods.org/pods/SyncKit)
[![Platform](https://img.shields.io/cocoapods/p/SyncKit.svg?style=flat)](http://cocoapods.org/pods/SyncKit)

SyncKit is a library for iOS and OS X that automates the process of synchronizing Core Data or Realm (ObjC) models using CloudKit.

SyncKit uses introspection to work with any model. It sits next to your Core Data or Realm stack, making it easy to opt in or out of synchronization without imposing any requirements on your model.

## Adding SyncKit to your project using Cocoapods

[CocoaPods](http://cocoapods.org) is a dependency manager for Swift and Objective-C Cocoa projects. Install Cocoapods if you don't have it already:

```bash
$ gem install cocoapods
```

And add SyncKit to your `Podfile`. Use the corresponding subspec based on what technology you use for you model:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

target 'CoreDataTargetName' do
pod 'SyncKit/CoreData', '~> 0.4'
end

target 'RealmTargetName' do
pod 'SyncKit/Realm', '~> 0.4'
end
```

Then install using:

```bash
$ pod install
```

## Adding SyncKit to your project using Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks. Install Carthage if you don't have it already:

```bash
$ brew install carthage
```

Add SyncKit to your `Cartfile`:

```
github "mentrena/SyncKit" ~> 0.4
```

Run `carthage update` to create the framework, then import it into your project.


## Requirements

Your application must have the right entitlements to use iCloud and CloudKit, and it must link against the CloudKit framework.
Your app is also responsible for handling the cases where a user has not signed into an iCloud account or the current iCloud account changes.

## How to use

There are two classes you need to be aware of: QSChangeManager and QSCloudKitSynchronizer.

QSChangeManager will track changes in your local model and coordinate what needs to be uploaded/downloaded to/from iCloud. Currently there are two implementations of the QSChangeManager protocol: QSCoreDataChangeManager and QSRealmChangeManager.

QSCloudKitSynchronizer will upload any pending changes from your change manager to CloudKit, and will pass downloaded changes from CloudKit to your change manager.

Import the right QSCloudKitSynchronizer category for your data stack and create a synchronizer:

**Core Data**

```objc

#import <SyncKit/QSCloudKitSynchronizer+CoreData.h>

...

self.synchronizer = [QSCloudKitSynchronizer cloudKitSynchronizerWithContainerName:@"your-container-name" managedObjectContext:self.managedObjectContext changeManagerDelegate:self];

...

//Synchronize
[self.synchronizer synchronizeWithCompletion:^(NSError *error) {
    if (error) {
        //Handle error
    }
}];
```

QSCoreDataChangeManager needs a QSCoreDataChangeManagerDelegate to save the local NSManagedObjectContext when needed. An example implementation:

```objc
//Change manager requests you save your managed object context
- (void)changeManagerRequestsContextSave:(QSCoreDataChangeManager *)changeManager completion:(void (^)(NSError *))completion
{
    __block NSError *error = nil;
    [self.managedObjectContext performBlockAndWait:^{
        [self.managedObjectContext save:&error];
    }];
    completion(error);
}

//Change manager provides a child context of your local managed object context, containing changes downloaded from CloudKit. Save the import context, then your local context to persist these changes.
- (void)changeManager:(QSCoreDataChangeManager *)changeManager didImportChanges:(NSManagedObjectContext *)importContext completion:(void (^)(BOOL, NSError *))completion
{
	__block NSError *error = nil;
    [importContext performBlockAndWait:^{
        [importContext save:&error];
    }];
    
    if (!error) {
        [self.managedObjectContext performBlockAndWait:^{
            [self.managedObjectContext save:&error];
        }];
    }
    completion(error);
}
```

You might want to add some extra logic if you don't always want to persist CloudKit changes, if you use an undo manager, or if your Core Data stack is more complex.

**Realm**

```objc

#import <SyncKit/QSCloudKitSynchronizer+Realm.h>

...

self.synchronizer = [QSCloudKitSynchronizer cloudKitSynchronizerWithContainerName:@"your-container-name" realmConfiguration:self.realm.configuration];

...

//Synchronize
[self.synchronizer synchronizeWithCompletion:^(NSError *error) {
    if (error) {
        //Handle error
    }
}];
```

## Identifying objects

**Core Data**

By default SyncKit will use the NSManagedObjectID of your objects to keep track of them, this allows your model to be completely agnostic to whether SyncKit is in use or not. However, there's two possible cases where this won't be enough:

- Objects A and A', created separately in different devices, should be considered the "same" object: You will likely have an identifier provided by yourself in this case and want object A to match A' when synchronizing your data.
- Your Core Data model might change in the future: any resulting migration, even if it's a lightweight migration, might cause your object IDs to change, thus rendering all SyncKit tracking data invalid.

To cope with these cases, as of version 0.3.0, your objects can conform to `QSPrimaryKey` and implement its `+ (nonnull NSString *)primaryKey` method to return the name of a stored property that should be used as primary key.
If you were using SyncKit before 0.3.0 and you want to adopt the `QSPrimaryKey` protocol you have two courses of action:

- If your objects already had a populated primary key: Make them implement `QSPrimaryKey` and call `updateTrackingForObjectsWithPrimaryKey` on the change manager to make it update its object tracking data so it uses the primary key.
- If you need to change your model to add a primary key: you can use `QSEntityIdentifierUpdateMigrationPolicy` as the policy in your mapping model, just call `[QSCloudKitSynchronizer updateIdentifierMigrationPolicy];` before starting the migration.

Or you could disable SyncKit and re-enable it with an empty NSPersistentStore to restore using data currently on iCloud.

**Realm**

Your model classes must have a primary key.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.
Because the sample project uses CloudKit you will need to use your Apple Developer account to create an app identifier and iCloud container. Then enable CloudKit for the app by going to your target Capabilities page and make sure the right container is accessible by the app.
In QSAppDelegate replace the sample container name with yours:

```objc

- (QSCloudKitSynchronizer *)synchronizer
{
    if (!_synchronizer) {
        _synchronizer = [QSCloudKitSynchronizer cloudKitSynchronizerWithContainerName:@"your-container-identifier" managedObjectContext:self.managedObjectContext changeManagerDelegate:self];
    }
    return _synchronizer;
}

```

You should then be able to run the sample app. 

## Limitations

**Core Data**

CloudKit doesn't support ordered relations or many-to-many relationships, so those won't work.

**Realm**

CloudKit doesn't support ordered relations or many-to-many relationships, so SyncKit will ignore your RLMArray properties. It is recommended to model your many-to-one relationships using RLMLinkingObjects and Object properties:

```objc
@interface QSCompany : RLMObject

@property (readonly) RLMLinkingObjects *employees;

@end

...

@interface QSEmployee : RLMObject

@property (nonatomic, strong) QSCompany *company;

@end

```

## Author

Manuel Entrena, manuel@mentrena.com

## License

SyncKit is available under the MIT license. See the LICENSE file for more info.
