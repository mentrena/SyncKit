# Changelog

## 0.7.9
### Changed
- Fixes for record reupload, RealmSwift non-optional properties.
- Sample project shows how to connect/disconnect SyncKit.

## 0.7.2
### Changed
- Ported all code to Swift.
- Updated sample project.

## 0.6.6
### Added
- Support for database subscriptions.

## 0.6.4
### Changed
- Fixes for sharing and UICloudSharingController.
- Updated to Swift 4.2

## 0.6.1
### Changed
- Requiring QSPrimaryKey for Core Data.

## 0.6.0

### Added
- Support for CloudKit sharing and multiple record zones.

### Changed
- Some of the APIs have changed.
- SyncKit now requires iOS 10+ or OS X 10.12+.

## 0.5.8
### Added
- SyncKit can use CKAsset for Data property types.

## 0.5.7
### Fixed
- Handling CKErrorUserDeletedZone error.

## 0.5.6
### Fixed
- Added @objc attribute to RealmSwift class properties.
- Detecting CKErrorLimitExceeded nested in CKErrorPartialFailure error.

## 0.5.5
### Added
- Updated iCloud APIs.
- Added support for Apple Watch.
- Updated Realm libraries.

## 0.5.2
### Added
- RealmSwiftChangeManager.

## 0.5.1
### Added
- Support for app groups, to store tracking data in shared app container.

## 0.5.0
### Removed
- WatchOS for now.

## 0.4.9
###Fixed
- Fixed issues with nil record keys and primary keys.

## 0.4.8
### Fixed
- toMany relationships getting record values.

## 0.4.7
### Fixed
- Prevent fetch operation from being released before completion block executed.

## 0.4.6
### Fixed
- Synchronization of nilled properties.
- Subscription handling.

## 0.4.5
### Fixed
- Realm threading and tracking.

## 0.4.4
### Fixed
- Cleaning up pending relationships after they're applied.
- CoreData Primary key not recognized when entity name is different from class name.

## 0.4.3
### Fixed
- Core Data iOS framework model.

## 0.4.2
### Fixed
- Realm tracking.

## 0.4.1
### Fixed
- Use ManagedObjectClassName instead of Name when getting entity class from NSEntityDescription.
- Example project models target membership.
- Sanitized Example workspace and added platform to podfile.

## 0.4.0
### Added
- Support for Realm.

## 0.3.3
### Fixed
- Using private queue for synchronizer.
- Example project storyboard compatibility.

## 0.3.2
### Added
- Download only mode.
- Performance improvements.
- Compatibility version number to facilitate model updates.

## 0.3.0

### Added
- QSPrimaryKey protocol for objects with a primary key, to support deduplication and migrations.
- Migration policy to preserve sync data when a Core Data model is migrated to add an identifier field, to support QSPrimaryKey

### Fixed
- Identifier update method.
