//
//  RecordProcessingDelegate.swift
//  SyncKitRealmExampleTests
//
//  Created by Manuel Entrena on 09/11/2020.
//  Copyright © 2020 Manuel Entrena. All rights reserved.
//

import Foundation
import CloudKit
import Realm
import SyncKit


class RecordProcessingDelegate: RealmAdapterRecordProcessing {
    
    var shouldProcessUploadClosure: ((String, RLMObject, CKRecord) -> Bool)?
    func shouldProcessPropertyBeforeUpload(propertyName: String, object: RLMObject, record: CKRecord) -> Bool {
        shouldProcessUploadClosure?(propertyName, object, record) ?? true
    }
    
    var shouldProcessDownloadClosure: ((String, RLMObject, CKRecord) -> Bool)?
    func shouldProcessPropertyInDownload(propertyName: String, object: RLMObject, record: CKRecord) -> Bool {
        shouldProcessDownloadClosure?(propertyName, object, record) ?? true
    }
}
