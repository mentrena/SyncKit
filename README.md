# SyncKit

[![CI Status](http://img.shields.io/travis/mentrena/SyncKit.svg?style=flat)](https://travis-ci.org/mentrena/SyncKit)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Version](https://img.shields.io/cocoapods/v/SyncKit.svg?style=flat)](http://cocoapods.org/pods/SyncKit)
[![License](https://img.shields.io/cocoapods/l/SyncKit.svg?style=flat)](http://cocoapods.org/pods/SyncKit)
[![Platform](https://img.shields.io/cocoapods/p/SyncKit.svg?style=flat)](http://cocoapods.org/pods/SyncKit)

SyncKit automates the process of synchronizing Core Data or Realm models using CloudKit.

SyncKit uses introspection to work with any model. It sits next to your Core Data or Realm stack, making it easy to opt in or out of synchronization without imposing any requirements on your model.

## Adding SyncKit to your project using Cocoapods

[CocoaPods](http://cocoapods.org) is a dependency manager for Swift and Objective-C Cocoa projects. Install Cocoapods if you don't have it already:

```bash
$ gem install cocoapods
```

And add SyncKit to your `Podfile`. Use the corresponding subspec based on what technology you use for you model:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'

target 'CoreDataTargetName' do
pod 'SyncKit/CoreData', '~> 0.6.0'
end

target 'RealmTargetName' do
pod 'SyncKit/Realm', '~> 0.6.0'
end

target 'RealmSwiftTargetName' do
pod 'SyncKit/RealmSwift', '~> 0.6.0'
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
github "mentrena/SyncKit" ~> 0.6.0
```

Run `carthage update` to create the framework, then import it into your project.

## Documentation

Find more information in the [Wiki](https://github.com/mentrena/SyncKit/wiki)
    

## Author

Manuel Entrena, manuel@mentrena.com

## License

SyncKit is available under the MIT license. See the LICENSE file for more info.
