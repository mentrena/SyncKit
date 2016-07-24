# SyncKit

[![CI Status](http://img.shields.io/travis/mentrena/SyncKit.svg?style=flat)](https://travis-ci.org/mentrena/SyncKit)
[![Version](https://img.shields.io/cocoapods/v/SyncKit.svg?style=flat)](http://cocoapods.org/pods/SyncKit)
[![License](https://img.shields.io/cocoapods/l/SyncKit.svg?style=flat)](http://cocoapods.org/pods/SyncKit)
[![Platform](https://img.shields.io/cocoapods/p/SyncKit.svg?style=flat)](http://cocoapods.org/pods/SyncKit)

SyncKit is a library for iOS and OS X that automates the process of synchronizing Core Data models using CloudKit.

SyncKit relies on the flexibility of Core Data and uses instrospection to work with any Core Data model. It sits next to your Core Data stack, making it easy to opt in or out of synchronization without imposing any requirements on your model.

## Adding SyncKit to your project using Cocoapods

[CocoaPods](http://cocoapods.org) is a dependency manager for Swift and Objective-C Cocoa projects. Install Cocoapods if you don't have it already:

```bash
$ gem install cocoapods
```

And add SyncKit to your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

target 'TargetName' do
pod 'SyncKit', '~> 0.1'
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
github "mentrena/SyncKit" ~> 0.1.0
```

Run `carthage update` to create the framework, then import it into your project.


## Requirements

Your application must have the right entitlements to use iCloud and CloudKit, and it must link against both the Core Data and CloudKit frameworks.

## How to use

There are two classes you need to be aware of: QSCoreDataChangeManager and QSCloudKitSynchronizer.

QSCoreDataChangeManager will track changes in your local model and coordinate what needs to be uploaded/downloaded to/from iCloud. It needs a QSCoreDataChangeManagerDelegate to save the local NSManagedObjectContext when needed. The simplest implementation of the delegate is as follows:

```objc
//Change manager requests you save your managed object context
- (void)changeManagerRequestsContextSave:(QSCoreDataChangeManager *)changeManager completion:(void (^)())completion
{
    [self.managedObjectContext save:nil];
    completion();
}

//Change manager provides a child context of your local managed object context, containing changes downloaded from CloudKit. Save the import context, then your local context to persist these changes.
- (void)changeManager:(QSCoreDataChangeManager *)changeManager didImportChanges:(NSManagedObjectContext *)importContext completion:(void (^)(BOOL, NSError *))completion
{
    [importContext performBlockAndWait:^{
        [importContext save:nil];
    }];

    [self.managedObjectContext save:nil];
    completion(YES, nil); //return YES if saved, or NO if you ignored these changes
}
```

But you might want to add some extra logic if you don't always want to persist CloudKit changes, if you use an undo manager, or if your Core Data stack is more complex.

QSCloudKitSynchronizer will upload any pending changes from your change manager to CloudKit, and will pass downloaded changes from CloudKit to your change manager. To synchronize your model create a new instance of QSCloudKitSynchronizer:

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

Your application should handle the cases where a user has not signed into an iCloud account or the current iCloud account changes.

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

## Author

Manuel Entrena, manuel@mentrena.com

## License

SyncKit is available under the MIT license. See the LICENSE file for more info.
