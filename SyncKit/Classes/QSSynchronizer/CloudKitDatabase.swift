//
//  CloudKitDatabase.swift
//  SyncKit
//
//  Created by Manuel Entrena on 09/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CloudKit

/*
 CloudKitDatabaseAdapter is a façade of the CKDatabase api, used by CloudKitSynchronizer instead of using CKDatabase directly,
 because this allows us to test the synchronizer.
 */

@objc public protocol CloudKitDatabaseAdapter {
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449116-add
    func add(_ operation: CKDatabaseOperation)
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449114-save
    func save(zone: CKRecordZone, completionHandler: @escaping (CKRecordZone?, Error?) -> Void)
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449104-fetch
    func fetch(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone?, Error?) -> Void)
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449126-fetch
    func fetch(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord?, Error?) -> Void)
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449118-delete
    func delete(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone.ID?, Error?) -> Void)
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1640398-databasescope
    var databaseScope: CKDatabase.Scope { get }
    
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449110-fetchallsubscriptions
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    func fetchAllSubscriptions(completionHandler: @escaping ([CKSubscription]?, Error?) -> Void)
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449102-save
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    func save(subscription: CKSubscription, completionHandler: @escaping (CKSubscription?, Error?) -> Void)
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/3003590-delete
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    func delete(withSubscriptionID subscriptionID: CKSubscription.ID, completionHandler: @escaping (String?, Error?) -> Void)
}

@objc public class DefaultCloudKitDatabaseAdapter: NSObject, CloudKitDatabaseAdapter {
    
    
    /// The `CKDatabase` used by this adapter
    public let database: CKDatabase
    
    /// Initialize a `DefaultCloudKitDatabaseAdapter` with a given `CKDatabase`. All calls to the adapter methods will be forwarded to the database instance.
    /// - Parameter database:
    public init(database: CKDatabase) {
        self.database = database
    }
    
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449116-add
    public func add(_ operation: CKDatabaseOperation) {
        database.add(operation)
    }
    
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449114-save
    public func save(zone: CKRecordZone, completionHandler: @escaping (CKRecordZone?, Error?) -> Void) {
        database.save(zone, completionHandler: completionHandler)
    }
    
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449104-fetch
    public func fetch(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone?, Error?) -> Void) {
        database.fetch(withRecordZoneID: zoneID, completionHandler: completionHandler)
    }
    
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449126-fetch
    public func fetch(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord?, Error?) -> Void) {
        database.fetch(withRecordID: recordID, completionHandler: completionHandler)
    }
    
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449118-delete
    public func delete(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone.ID?, Error?) -> Void) {
        database.delete(withRecordZoneID: zoneID, completionHandler: completionHandler)
    }
    
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1640398-databasescope
    public var databaseScope: CKDatabase.Scope {
        return database.databaseScope
    }
    
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449110-fetchallsubscriptions
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    public func fetchAllSubscriptions(completionHandler: @escaping ([CKSubscription]?, Error?) -> Void) {
        database.fetchAllSubscriptions(completionHandler: completionHandler)
    }
    
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/1449102-save
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    public func save(subscription: CKSubscription, completionHandler: @escaping (CKSubscription?, Error?) -> Void) {
        database.save(subscription, completionHandler: completionHandler)
    }
    
    /// See https://developer.apple.com/documentation/cloudkit/ckdatabase/3003590-delete
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    public func delete(withSubscriptionID subscriptionID: CKSubscription.ID, completionHandler: @escaping (String?, Error?) -> Void) {
        database.delete(withSubscriptionID: subscriptionID, completionHandler: completionHandler)
    }
}
