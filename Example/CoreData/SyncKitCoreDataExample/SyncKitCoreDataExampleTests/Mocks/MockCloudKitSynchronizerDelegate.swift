//
//  MockCloudKitSynchronizerDelegate.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel on 27/07/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//

import Foundation
import CloudKit
import SyncKit

class MockCloudKitSynchronizerDelegate: CloudKitSynchronizerDelegate {
    
    var synchronizerWillStartSyncingCalled = false
    func synchronizerWillStartSyncing(_ synchronizer: CloudKitSynchronizer) {
        synchronizerWillStartSyncingCalled = true
    }
    
    var synchronizerWillCheckForChangesCalled = false
    func synchronizerWillCheckForChanges(_ synchronizer: CloudKitSynchronizer) {
        synchronizerWillCheckForChangesCalled = true
    }
    
    var synchronizerWillFetchChangesCalled = false
    func synchronizerWillFetchChanges(_ synchronizer: CloudKitSynchronizer, in recordZone: CKRecordZone.ID) {
        synchronizerWillFetchChangesCalled = true
    }
    
    var synchronizerDidFetchChangesCalled = false
    func synchronizerDidFetchChanges(_ synchronizer: CloudKitSynchronizer, in recordZone: CKRecordZone.ID) {
        synchronizerDidFetchChangesCalled = true
    }
    
    var synchronizerWillUploadChangesCalled = false
    func synchronizerWillUploadChanges(_ synchronizer: CloudKitSynchronizer, to recordZone: CKRecordZone.ID) {
        synchronizerWillUploadChangesCalled = true
    }
    
    var synchronizerDidSyncCalled = false
    func synchronizerDidSync(_ synchronizer: CloudKitSynchronizer) {
        synchronizerDidSyncCalled = true
    }
    
    var synchronizerDidfailToSyncCalled = false
    func synchronizerDidfailToSync(_ synchronizer: CloudKitSynchronizer, error: Error) {
        synchronizerDidfailToSyncCalled = true
    }
    
    var synchronizerDidAddAdapter = [CKRecordZone.ID: ModelAdapter]()
    func synchronizer(_ synchronizer: CloudKitSynchronizer, didAddAdapter adapter: ModelAdapter, forRecordZoneID zoneID: CKRecordZone.ID) {
        synchronizerDidAddAdapter[zoneID] = adapter
    }
    
    var synchronizerZoneIDWasDeleted = [CKRecordZone.ID]()
    func synchronizer(_ synchronizer: CloudKitSynchronizer, zoneIDWasDeleted zoneID: CKRecordZone.ID) {
        synchronizerZoneIDWasDeleted.append(zoneID)
    }
}
