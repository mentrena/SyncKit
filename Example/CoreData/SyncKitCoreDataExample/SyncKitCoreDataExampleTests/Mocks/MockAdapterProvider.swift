//
//  MockAdapterProvider.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 12/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import SyncKit
import CloudKit

class MockAdapterProvider: AdapterProvider {
    
    var modelAdapterValue: ModelAdapter?
    var modelAdapterForRecordZoneIDCalled = false
    func cloudKitSynchronizer(_ synchronizer: CloudKitSynchronizer, modelAdapterForRecordZoneID zoneID: CKRecordZone.ID) -> ModelAdapter? {
       modelAdapterForRecordZoneIDCalled = true
        return modelAdapterValue
    }
    
    var zoneWasDeletedWithIDCalled = false
    func cloudKitSynchronizer(_ synchronizer: CloudKitSynchronizer, zoneWasDeletedWithZoneID zoneID: CKRecordZone.ID) {
        zoneWasDeletedWithIDCalled = true
    }
}
