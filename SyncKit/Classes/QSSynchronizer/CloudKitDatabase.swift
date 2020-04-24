//
//  CloudKitDatabase.swift
//  SyncKit
//
//  Created by Manuel Entrena on 09/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CloudKit

@objc public protocol CloudKitDatabaseAdapter {
    func add(_ operation: CKDatabaseOperation)
    func save(zone: CKRecordZone, completionHandler: @escaping (CKRecordZone?, Error?) -> Void)
    func fetch(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone?, Error?) -> Void)
    func delete(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone.ID?, Error?) -> Void)
    var databaseScope: CKDatabase.Scope { get }
    
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    func fetchAllSubscriptions(completionHandler: @escaping ([CKSubscription]?, Error?) -> Void)
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    func save(subscription: CKSubscription, completionHandler: @escaping (CKSubscription?, Error?) -> Void)
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    func delete(withSubscriptionID subscriptionID: CKSubscription.ID, completionHandler: @escaping (String?, Error?) -> Void)
}

@objc public class DefaultCloudKitDatabaseAdapter: NSObject, CloudKitDatabaseAdapter {
    
    public let database: CKDatabase
    public init(database: CKDatabase) {
        self.database = database
    }
    
    public func add(_ operation: CKDatabaseOperation) {
        database.add(operation)
    }
    
    public func save(zone: CKRecordZone, completionHandler: @escaping (CKRecordZone?, Error?) -> Void) {
        database.save(zone, completionHandler: completionHandler)
    }
    
    public func fetch(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone?, Error?) -> Void) {
        database.fetch(withRecordZoneID: zoneID, completionHandler: completionHandler)
    }
    
    public func delete(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone.ID?, Error?) -> Void) {
        database.delete(withRecordZoneID: zoneID, completionHandler: completionHandler)
    }
    
    public var databaseScope: CKDatabase.Scope {
        return database.databaseScope
    }
    
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    public func fetchAllSubscriptions(completionHandler: @escaping ([CKSubscription]?, Error?) -> Void) {
        database.fetchAllSubscriptions(completionHandler: completionHandler)
    }
    
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    public func save(subscription: CKSubscription, completionHandler: @escaping (CKSubscription?, Error?) -> Void) {
        database.save(subscription, completionHandler: completionHandler)
    }
    
    @available(iOS 10.0, macOS 10.12, watchOS 6.0, *)
    public func delete(withSubscriptionID subscriptionID: CKSubscription.ID, completionHandler: @escaping (String?, Error?) -> Void) {
        database.delete(withSubscriptionID: subscriptionID, completionHandler: completionHandler)
    }
}
