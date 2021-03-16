//
//  DefaultCoreDataStackProviderTests.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 11/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import XCTest
@testable import SyncKit
import CoreData
import CloudKit

class DefaultCoreDataStackProviderTests: XCTestCase {
    
    var provider: DefaultCoreDataStackProvider!
    
    override func setUp() {
        super.setUp()
        
        provider = createProvider(id: "provider1")
    }
    
    override func tearDown() {
        clearProviderDirectory(for: provider)
        provider = nil
        super.tearDown()
    }
    
    func objectModel() -> NSManagedObjectModel {
        let url = Bundle(for: DefaultCoreDataStackProviderTests.self).url(forResource: "QSExample", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: url)!
    }
    
    func createProvider(id: String) -> DefaultCoreDataStackProvider {
        return DefaultCoreDataStackProvider(identifier: id, storeType: NSSQLiteStoreType, model: objectModel())
    }
    
    func createSynchronizer() -> CloudKitSynchronizer {
        return CloudKitSynchronizer(identifier: "", containerIdentifier: "", database: MockCloudKitDatabase(), adapterProvider: provider)
    }
    
    func directoryForProvider(identifier: String) -> URL {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).last!.appendingPathComponent("Stores").appendingPathComponent(identifier)
    }
    
    func filesInProviderDirectory(for provider: DefaultCoreDataStackProvider) -> Int {
        let directoryURL = provider.directoryURL!
        let enumerator = FileManager.default.enumerator(at: directoryURL, includingPropertiesForKeys: [.nameKey, .isDirectoryKey], options: .skipsSubdirectoryDescendants)!
        return enumerator.allObjects.count
    }
    
    func clearProviderDirectory(for provider: DefaultCoreDataStackProvider) {
        let changeManager = provider.adapterDictionary.values.first
        changeManager?.deleteChangeTracking()
        
        let stack = provider.coreDataStacks.values.first
        stack?.deleteStore()
        
        let directoryURL = provider.directoryURL!
        try? FileManager.default.removeItem(at: directoryURL)
    }
    
    func testChangeManagerForRecordZoneID_createsNewChangeManagerAndStack() {
        XCTAssertEqual(filesInProviderDirectory(for: provider), 0)
        let synchronizer = createSynchronizer()
        let recordZoneID = CKRecordZone.ID(zoneName: "zone", ownerName: "owner")
        let changeManager = provider.cloudKitSynchronizer(synchronizer, modelAdapterForRecordZoneID: recordZoneID) as? CoreDataAdapter
        XCTAssertNotNil(changeManager)
        XCTAssertNotNil(changeManager?.targetContext)
        XCTAssertNotNil(changeManager?.stack.managedObjectContext)
        XCTAssertEqual(changeManager?.recordZoneID, recordZoneID)
        XCTAssertEqual(provider.adapterDictionary.count, 1)
        XCTAssertEqual(provider.coreDataStacks.count, 1)
        XCTAssertTrue(filesInProviderDirectory(for: provider) > 0)
    }
    
    func testInit_existingStacks_createsChangeManagers() {
        let directoryURL = directoryForProvider(identifier: "provider2")
        let targetStoreURL = directoryURL.appendingPathComponent("zoneName.zoneID.zoneOwner").appendingPathComponent("QSTargetStore")
        let persistencenceStoreURL = directoryURL.appendingPathComponent("zoneName.zoneID.zoneOwner").appendingPathComponent("QSPersistenceStore")
        let _ = CoreDataStack(storeType: NSSQLiteStoreType, model: objectModel(), storeURL: targetStoreURL)
        let _ = CoreDataStack(storeType: NSSQLiteStoreType, model: CoreDataAdapter.persistenceModel, storeURL: persistencenceStoreURL)
        
        let newProvider = createProvider(id: "provider2")
        
        XCTAssertEqual(newProvider.adapterDictionary.count, 1)
        XCTAssertEqual(newProvider.coreDataStacks.count, 1)
        
        clearProviderDirectory(for: newProvider)
    }
    
    func testZoneWasDeletedWithZoneID_changeManagerHadBeenUsed_deletesChangeManagerAndRemovesFiles() {
        let recordZoneID = CKRecordZone.ID(zoneName: "zone", ownerName: "owner")
        let synchronizer = createSynchronizer()
        let adapter = provider.cloudKitSynchronizer(synchronizer, modelAdapterForRecordZoneID: recordZoneID) as? CoreDataAdapter
        adapter?.saveToken(CKServerChangeToken.stub())
        
        XCTAssertNotNil(adapter)
        XCTAssertEqual(provider.adapterDictionary.count, 1)
        
        provider.cloudKitSynchronizer(synchronizer, zoneWasDeletedWithZoneID: recordZoneID)
        
        XCTAssertEqual(provider.adapterDictionary.count, 0)
        XCTAssertEqual(provider.coreDataStacks.count, 0)
    }
    
    func testZoneWasDeletedWithZoneID_changeManagerHadNotBeenUsedYet_preservesChangeManagerSoZoneCanBeRecreated() {
        let recordZoneID = CKRecordZone.ID(zoneName: "zone", ownerName: "owner")
        let synchronizer = createSynchronizer()
        let adapter = provider.cloudKitSynchronizer(synchronizer, modelAdapterForRecordZoneID: recordZoneID) as? CoreDataAdapter
        
        XCTAssertNotNil(adapter)
        XCTAssertEqual(provider.adapterDictionary.count, 1)
        
        provider.cloudKitSynchronizer(synchronizer, zoneWasDeletedWithZoneID: recordZoneID)
        
        XCTAssertEqual(provider.adapterDictionary.count, 1)
        XCTAssertEqual(provider.coreDataStacks.count, 1)
    }
}
