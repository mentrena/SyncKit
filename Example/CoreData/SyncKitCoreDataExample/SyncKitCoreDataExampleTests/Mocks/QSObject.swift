//
//  QSObject.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 12/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import SyncKit
import CloudKit

class QSObject: Codable, Equatable {
    static func == (lhs: QSObject, rhs: QSObject) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    var number: Int?
    var identifier: String
    
    init(identifier: String, number: Int?) {
        self.identifier = identifier
        self.number = number
    }
    
    convenience init(record: CKRecord) {
        self.init(identifier: record.recordID.recordName, number: record["number"])
    }
    
    func record(with zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: "object", recordID: CKRecord.ID(recordName: identifier, zoneID: zoneID))
        record["number"] = number
        return record
    }
    
    func recordID(zoneID: CKRecordZone.ID) -> CKRecord.ID {
        return CKRecord.ID(recordName: identifier, zoneID: zoneID)
    }
    
    func save(record: CKRecord) {
        number = record["number"]
    }
}
