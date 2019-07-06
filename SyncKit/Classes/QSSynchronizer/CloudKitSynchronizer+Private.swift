//
//  CloudKitSynchronizer+Private.swift
//  OCMock
//
//  Created by Manuel Entrena on 05/04/2019.
//

import Foundation
import CloudKit

private let customZoneName = "QSCloudKitCustomZoneName"
private let storedDeviceUUIDKey = "QSCloudKitStoredDeviceUUIDKey"
private let subscriptionIdentifierKey = "QSSubscriptionIdentifierKey"
private let databaseServerChangeTokenKey = "QSDatabaseServerChangeTokenKey"

extension CloudKitSynchronizer {
    
    static var defaultCustomZoneID: CKRecordZone.ID {
        return CKRecordZone.ID(zoneName: customZoneName, ownerName: CKCurrentUserDefaultName)
    }
    
    var deviceUUID: String? {
        get {
            return keyValueStore.object(forKey: userDefaultsKey(for: storedDeviceUUIDKey)) as? String
        }
        set {
            let key = userDefaultsKey(for: storedDeviceUUIDKey)
            if let value = newValue {
                keyValueStore.set(value: value, forKey: key)
            } else {
                keyValueStore.removeObject(forKey: key)
            }
        }
    }
    
    var storedDatabaseToken: CKServerChangeToken? {
        get {
            guard let encodedToken = keyValueStore.object(forKey: userDefaultsKey(for: databaseServerChangeTokenKey)) as? Data else {
                return nil
            }
            
            return QSCoder.shared.object(from: encodedToken) as? CKServerChangeToken
        }
        set {
            let key = userDefaultsKey(for: databaseServerChangeTokenKey)
            if let token = newValue,
                let encodedToken = QSCoder.shared.data(from: token) {
                keyValueStore.set(value: encodedToken, forKey: key)
            } else {
                keyValueStore.removeObject(forKey: key)
            }
        }
    }
    
    var databaseSubscriptionID: String? {
        get {
            return getStoredSubscriptionIDsDictionary()?[storeKey(for: database)]
        }
        set {
            var dictionary: [String: String]! = getStoredSubscriptionIDsDictionary()
            if dictionary == nil {
                dictionary = [String: String]()
            }
            dictionary[storeKey(for: database)] = newValue
            setStoredSubscriptionIDsDictionary(dictionary)
        }
    }
    
    func getStoredSubscriptionID(for recordZoneID: CKRecordZone.ID) -> String? {
        return getStoredSubscriptionIDsDictionary()?[storeKey(for: recordZoneID)]
    }
    
    func storeSubscriptionID(_ subscriptionID: String, for recordZoneID: CKRecordZone.ID) {
        var dictionary: [String: String]! = getStoredSubscriptionIDsDictionary()
        if dictionary == nil {
            dictionary = [String: String]()
        }
        dictionary[storeKey(for: recordZoneID)] = subscriptionID
        setStoredSubscriptionIDsDictionary(dictionary)
    }
    
    func clearSubscriptionID(_ subscriptionID: String) {
        var dictionary: [String: String]? = getStoredSubscriptionIDsDictionary()
        dictionary = dictionary?.filter { $0.value != subscriptionID}
        setStoredSubscriptionIDsDictionary(dictionary)
    }
    
    func clearAllStoredSubscriptionIDs() {
        setStoredSubscriptionIDsDictionary(nil)
    }
    
    func addMetadata(to records: [CKRecord]) {
        records.forEach {
            $0[CloudKitSynchronizer.deviceUUIDKey] = self.deviceIdentifier
            if self.compatibilityVersion > 0 {
                $0[CloudKitSynchronizer.modelCompatibilityVersionKey] = self.compatibilityVersion
            }
        }
    }
    
    fileprivate func getStoredSubscriptionIDsDictionary() -> [String: String]? {
        return keyValueStore.object(forKey: userDefaultsKey(for: subscriptionIdentifierKey)) as? [String: String]
    }
    
    fileprivate func setStoredSubscriptionIDsDictionary(_ dict: [String: String]?) {
        let key = userDefaultsKey(for: subscriptionIdentifierKey)
        if dict != nil {
            keyValueStore.set(value: dict, forKey: key)
        } else {
            keyValueStore.removeObject(forKey: key)
        }
    }
    
    fileprivate func userDefaultsKey(for key: String) -> String {
        return "\(containerIdentifier)-\(identifier)-\(key)"
    }
    
    fileprivate func storeKey(for zoneID: CKRecordZone.ID) -> String {
        return userDefaultsKey(for: "\(zoneID.ownerName).\(zoneID.zoneName)")
    }
    
    fileprivate func storeKey(for database: CloudKitDatabaseAdapter) -> String {
        return userDefaultsKey(for: "\(database.databaseScope == .private ? "privateDatabase" : "sharedDatabase")")
    }
}
