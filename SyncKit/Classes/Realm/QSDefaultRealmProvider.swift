//
//  QSDefaultRealmProvider.swift
//  Pods
//
//  Created by Manuel Entrena on 25/05/2018.
//

import Foundation
import CloudKit

public extension Notification.Name {
    public static let didAddAdapter = NSNotification.Name("didAddAdapter")
    public static let didRemoveAdapter = NSNotification.Name("didRemoveAdapter")
}

@objc public extension NSNotification {
    @objc public static let QSDefaultRealmProviderDidAddAdapterNotification: NSString = "didAddAdapter"
    @objc public static let QSDefaultRealmProviderDidRemoveAdapterNotification: NSString = "didRemoveAdapter"
}

@objc public class QSDefaultRealmProvider: NSObject, QSCloudKitSynchronizerAdapterProvider {
    
    @objc let identifier: String
    @objc public private(set) var adapterDictionary: [CKRecordZone.ID: QSRealmAdapter]
    @objc public private(set) var realms: [CKRecordZone.ID: RLMRealmConfiguration]
    @objc let appGroup: String?
    @objc let realmConfiguration: RLMRealmConfiguration
    
    private let QSDefaultRealmProviderTargetFileName = "QSDefaultRealmProviderTargetFileName"
    private let QSDefaultRealmProviderPersistenceFileName = "QSDefaultRealmProviderPersistenceFileName"
    
    @objc public init(identifier: String, realmConfiguration: RLMRealmConfiguration, appGroup: String?) {
        self.identifier = identifier
        self.appGroup = appGroup
        adapterDictionary = [CKRecordZone.ID: QSRealmAdapter]()
        realms = [CKRecordZone.ID: RLMRealmConfiguration]()
        self.realmConfiguration = realmConfiguration
        super.init()
        bringUpDataStacks()
    }
    
    private class func applicationDocumentsDirectory() -> String {
        
        #if os(iOS)
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last!
        #else
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls.last!.appendingPathComponent("com.mentrena.QSCloudKitSynchronizer").path
        #endif
    }
    
    private class func applicationDocumentsDirectoryForAppGroup(_ suiteName: String?) -> String {
        
        if let suiteName = suiteName {
            return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)!.path
        } else {
            return applicationDocumentsDirectory()
        }
    }
    
    private func stackProviderStoresPath(appGroup: String?) -> String {
        let documentsDirectory = QSDefaultRealmProvider.applicationDocumentsDirectoryForAppGroup(appGroup) as NSString
        let storesPath = documentsDirectory.appendingPathComponent("Stores") as NSString
        return storesPath.appendingPathComponent(identifier)
    }
    
    private var directoryURL: URL {
        return URL(fileURLWithPath: stackProviderStoresPath(appGroup: appGroup))
    }
    
    private func bringUpDataStacks() {
        
        let folderURL = URL(fileURLWithPath: stackProviderStoresPath(appGroup: appGroup))
        if let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: [URLResourceKey.nameKey, URLResourceKey.isDirectoryKey], options: [.skipsSubdirectoryDescendants]) {
            
            for case let url as URL in enumerator {
                let folderName = url.lastPathComponent
                let zoneIDComponents = folderName.components(separatedBy: ".zoneID.")
                let zoneID = CKRecordZone.ID(zoneName: zoneIDComponents[0], ownerName: zoneIDComponents[1])
                let stackURL = url.appendingPathComponent(QSDefaultRealmProviderTargetFileName)
                let persistenceURL = url.appendingPathComponent(QSDefaultRealmProviderPersistenceFileName)
                let adapter = realmAdapterFor(targetRealmURL:stackURL, persistenceRealmURL: persistenceURL, zoneID: zoneID)
                adapterDictionary[zoneID] = adapter
            }
        }
        
    }
    
    private func realmAdapterFor(targetRealmURL: URL, persistenceRealmURL: URL, zoneID: CKRecordZone.ID) -> QSRealmAdapter {
        
        let targetConfiguration = self.realmConfiguration.copy() as! RLMRealmConfiguration
        targetConfiguration.fileURL = targetRealmURL
        
        let persistenceConfiguration = QSRealmAdapter.defaultPersistenceConfiguration()
        persistenceConfiguration.fileURL = persistenceRealmURL
        
        realms[zoneID] = targetConfiguration
        
        return QSRealmAdapter(persistenceRealmConfiguration: persistenceConfiguration, targetRealmConfiguration: targetConfiguration, recordZoneID: zoneID)
    }
    
    private func folderNameFor(recordZoneID: CKRecordZone.ID) -> String {
        return recordZoneID.zoneName + ".zoneID." + recordZoneID.ownerName
    }
    
    @objc public func cloudKitSynchronizer(_ synchronizer: QSCloudKitSynchronizer, modelAdapterFor recordZoneID: CKRecordZone.ID) -> QSModelAdapter? {
        
        if let adapter = adapterDictionary[recordZoneID] {
            return adapter
        }
        
        let folderName = folderNameFor(recordZoneID: recordZoneID)
        let folderURL = directoryURL.appendingPathComponent(folderName)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let stackURL = folderURL.appendingPathComponent(QSDefaultRealmProviderTargetFileName)
        let persistenceURL = folderURL.appendingPathComponent(QSDefaultRealmProviderPersistenceFileName)
        
        let adapter = realmAdapterFor(targetRealmURL: stackURL, persistenceRealmURL: persistenceURL, zoneID: recordZoneID)
        
        adapterDictionary[recordZoneID] = adapter
        
        NotificationCenter.default.post(name: .didAddAdapter, object: self, userInfo:["CKRecordZoneID": recordZoneID])
        
        return adapter
    }
    
    @objc public func cloudKitSynchronizer(_ synchronizer: QSCloudKitSynchronizer, zoneWasDeletedWith recordZoneID: CKRecordZone.ID) {
        
        guard let adapter = adapterDictionary[recordZoneID],
            adapter.serverChangeToken() != nil else {
                return
        }
        
        adapter.deleteChangeTracking()
        
        adapterDictionary[recordZoneID] = nil
        realms[recordZoneID] = nil

        synchronizer.removeModelAdapter(adapter)
        
        let folderName = folderNameFor(recordZoneID: recordZoneID)
        let folderURL = directoryURL.appendingPathComponent(folderName)
        try? FileManager.default.removeItem(at: folderURL)
        
        NotificationCenter.default.post(name: .didRemoveAdapter, object: self, userInfo:["CKRecordZoneID": recordZoneID])
    }
}
