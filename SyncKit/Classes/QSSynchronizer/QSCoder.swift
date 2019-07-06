//
//  Coder.swift
//  Pods
//
//  Created by Manuel Entrena on 09/06/2019.
//

import Foundation
import CloudKit

class QSCoder {
    
    static let shared = QSCoder()
    
    func data(from object: Any, secure: Bool = false) -> Data? {
        return NSKeyedArchiver.archivedData(withRootObject: object)
    }
    
    func object(from data: Data) -> Any? {
        return NSKeyedUnarchiver.unarchiveObject(with: data)
    }
    
    func encode<T: CKRecord>(_ record: T, onlySystemFields: Bool = false) -> Data {
        if #available(iOS 12, OSX 10.13, watchOS 4.0, *) {
            let archiver = NSKeyedArchiver(requiringSecureCoding: false)
            if onlySystemFields {
                record.encodeSystemFields(with: archiver)
            } else {
                record.encode(with: archiver)
            }
            archiver.finishEncoding()
            return archiver.encodedData
        } else {
            let data = NSMutableData()
            let archiver = NSKeyedArchiver(forWritingWith: data)
            if onlySystemFields {
                record.encodeSystemFields(with: archiver)
            } else {
                record.encode(with: archiver)
            }
            archiver.finishEncoding()
            return data as Data
        }
    }
    
    func decode<T: CKRecord>(from data: Data) -> T? {
        var unarchiver: NSKeyedUnarchiver?
        if #available(iOS 12, OSX 10.13, watchOS 4.0, *) {
            unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data)
        } else {
            unarchiver = NSKeyedUnarchiver(forReadingWith: data)
        }
        guard let coder = unarchiver else { return nil }
        let record = T(coder: coder)
        coder.finishDecoding()
        return record
    }
}
