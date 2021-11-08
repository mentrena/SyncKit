//
//  RecordProcessingDelegate.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 09/11/2020.
//  Copyright © 2020 Manuel Entrena. All rights reserved.
//

import Foundation
import CoreData
import CloudKit
import SyncKit

class RecordProcessingDelegate: CoreDataAdapterRecordProcessing {
    
    var shouldProcessUploadClosure: ((String, NSManagedObject, CKRecord) -> Bool)?
    func shouldProcessPropertyBeforeUpload(propertyName: String, object: NSManagedObject, record: CKRecord) -> Bool {
        shouldProcessUploadClosure?(propertyName, object, record) ?? true
    }
    
    var shouldProcessDownloadClosure: ((String, NSManagedObject, CKRecord) -> Bool)?
    func shouldProcessPropertyInDownload(propertyName: String, object: NSManagedObject, record: CKRecord) -> Bool {
        shouldProcessDownloadClosure?(propertyName, object, record) ?? true
    }
}
