//
//  RecordProcessingDelegate.swift
//  SyncKitRealmSwiftExampleTests
//
//  Created by Manuel Entrena on 09/11/2020.
//  Copyright © 2020 Manuel Entrena. All rights reserved.
//

import Foundation
import CloudKit
import RealmSwift
import SyncKit


class RecordProcessingDelegate: RealmSwiftAdapterRecordProcessing {
    
    var shouldProcessUploadClosure: ((String, Object, CKRecord) -> Bool)?
    func shouldProcessPropertyBeforeUpload(propertyName: String, object: Object, record: CKRecord) -> Bool {
        shouldProcessUploadClosure?(propertyName, object, record) ?? true
    }
    
    var shouldProcessDownloadClosure: ((String, Object, CKRecord) -> Bool)?
    func shouldProcessPropertyInDownload(propertyName: String, object: Object, record: CKRecord) -> Bool {
        shouldProcessDownloadClosure?(propertyName, object, record) ?? true
    }
}
