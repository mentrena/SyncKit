//
//  CloudKitDatabase.swift
//  SyncKit
//
//  Created by Manuel Entrena on 09/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import CloudKit

public protocol CloudKitDatabase {
    func add(_ operation: CKDatabaseOperation)
    func save(_ zone: CKRecordZone, completionHandler: @escaping (CKRecordZone?, Error?) -> Void)
    func fetchAllSubscriptions(completionHandler: @escaping ([CKSubscription]?, Error?) -> Void)
    func save(_ subscription: CKSubscription, completionHandler: @escaping (CKSubscription?, Error?) -> Void)
    func delete(withSubscriptionID subscriptionID: CKSubscription.ID, completionHandler: @escaping (String?, Error?) -> Void)
    func fetch(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone?, Error?) -> Void)
    func delete(withRecordZoneID zoneID: CKRecordZone.ID, completionHandler: @escaping (CKRecordZone.ID?, Error?) -> Void)
    var databaseScope: CKDatabase.Scope { get }
}

extension CKDatabase: CloudKitDatabase { }
