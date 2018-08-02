//  Converted to Swift 4 by Swiftify v4.1.6781 - https://objectivec2swift.com/
//
//  QSCloudKitSynchronizer+Private.swift
//  SyncKitCoreData
//
//  Created by Manuel Entrena on 02/12/2017.
//  Copyright © 2017 Colourbox. All rights reserved.
//

import CloudKit

let QSCloudKitDeviceUUIDKey = ""
let QSCloudKitModelCompatibilityVersionKey = ""
private let QSCloudKitCustomZoneName = "QSCloudKitCustomZoneName"
private let QSCloudKitStoredDeviceUUIDKey = "QSCloudKitStoredDeviceUUIDKey"
private let QSSubscriptionIdentifierKey = "QSSubscriptionIdentifierKey"
private let QSDatabaseServerChangeTokenKey = "QSDatabaseServerChangeTokenKey"

extension QSCloudKitSynchronizer {
    private(set) var deviceIdentifier = ""
    private(set) var dispatchQueue: DispatchQueue?

    class func defaultCustomZoneID() -> CKRecordZoneID? {
        return CKRecordZoneID(zoneName: QSCloudKitCustomZoneName, ownerName: CKCurrentUserDefaultName)
    }

    func getStoredDeviceUUID() -> String? {
        return keyValueStore[userDefaultsKey(forKey: QSCloudKitStoredDeviceUUIDKey)] as? String
    }

    func storeDeviceUUID(_ value: String?) {
        let key = userDefaultsKey(forKey: QSCloudKitStoredDeviceUUIDKey)
        if value != nil {
            keyValueStore[key] = value
        } else {
            keyValueStore.removeValueForKey(key)
        }
    }

    func getStoredDatabaseToken() -> CKServerChangeToken? {
        let encodedToken = keyValueStore[userDefaultsKey(forKey: QSDatabaseServerChangeTokenKey)] as? Data
        if let aToken = encodedToken {
            return encodedToken != nil ? NSKeyedUnarchiver.unarchiveObject(with: aToken) : nil as? CKServerChangeToken
        }
        return nil
    }

    func storeDatabaseToken(_ token: CKServerChangeToken?) {
        let key = userDefaultsKey(forKey: QSDatabaseServerChangeTokenKey)
        if token != nil {
            var encodedToken: Data? = nil
            if let aToken = token {
                encodedToken = NSKeyedArchiver.archivedData(withRootObject: aToken)
            }
            keyValueStore[key] = encodedToken
        } else {
            keyValueStore.removeValueForKey(key)
        }
    }

    func storedSubscriptionID(for zoneID: CKRecordZoneID?) -> String? {
        let subscriptionIDsDictionary = getStoredSubscriptionIDsDictionary()
        return subscriptionIDsDictionary?[storeKey(for: zoneID) ?? ""] as? String
    }

    func storeSubscriptionID(_ subscriptionID: String?, for zoneID: CKRecordZoneID?) {
        var subscriptionIDsDictionary = getStoredSubscriptionIDsDictionary()
        if subscriptionIDsDictionary == nil {
            subscriptionIDsDictionary = [AnyHashable : Any]()
        }
        subscriptionIDsDictionary?[storeKey(for: zoneID) ?? ""] = subscriptionID ?? ""
        setStoredSubscriptionIDsDictionary(subscriptionIDsDictionary)
    }

    func clearSubscriptionID(_ subscriptionID: String?) {
        var subscriptionIDsDictionary = getStoredSubscriptionIDsDictionary()
        var newDictionary: [AnyHashable : Any] = [:]
        subscriptionIDsDictionary?.enumerateKeysAndObjects(usingBlock: { key, identifier, stop in
            if !(identifier == subscriptionID) {
                newDictionary[key] = identifier
            }
        })
        setStoredSubscriptionIDsDictionary(newDictionary)
    }

    func clearAllStoredSubscriptionIDs() {
        setStoredSubscriptionIDsDictionary(nil)
    }

    func addMetadata(toRecords records: [Any]?) {
        for record: CKRecord? in records as? [CKRecord?] ?? [CKRecord?]() {
            record?[QSCloudKitDeviceUUIDKey] = deviceIdentifier
            if compatibilityVersion > 0 {
                record?[QSCloudKitModelCompatibilityVersionKey] = compatibilityVersion
            }
        }
    }

    func userDefaultsKey(forKey key: String?) -> String? {
        return "\(containerIdentifier)-\(identifier)-\(key ?? "")"
    }

    func storeKey(for zoneID: CKRecordZoneID?) -> String? {
        return userDefaultsKey(forKey: "\(zoneID?.ownerName ?? "").\(zoneID?.zoneName ?? "")")
    }

    func getStoredSubscriptionIDsDictionary() -> [AnyHashable : Any]? {
        return keyValueStore[userDefaultsKey(forKey: QSSubscriptionIdentifierKey)] as? [AnyHashable : Any]
    }

    func setStoredSubscriptionIDsDictionary(_ dictionary: [AnyHashable : Any]?) {
        let key = userDefaultsKey(forKey: QSSubscriptionIdentifierKey)
        if dictionary != nil {
            keyValueStore[key] = dictionary
        } else {
            keyValueStore.removeValueForKey(key)
        }
    }
}