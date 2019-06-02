//
//  TestUtilities.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 14/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import XCTest
import CloudKit
@testable import SyncKitRealmExample

extension CKServerChangeToken {
    static func stub() -> CKServerChangeToken {
        let fileURL = Bundle(for: SyncKitRealmTests.self).url(forResource: "serverChangeToken.AQAAAWPa1DUC", withExtension: "")!
        let data = NSData(contentsOf: fileURL)!
        return NSKeyedUnarchiver.unarchiveObject(with: data as Data) as! CKServerChangeToken
    }
}

extension QSCompany {
    static func stubbedRecord() -> CKRecord {
        let fileURL = Bundle(for: SyncKitRealmTests.self).url(forResource: "QSCompany.1739C6A5-C07E-48A5-B83E-AB07694F23DF", withExtension: "")!
        let data = NSData(contentsOf: fileURL)!
        let unarchiver = try! NSKeyedUnarchiver(forReadingFrom: data as Data)
        let record = CKRecord(coder: unarchiver)
        unarchiver.finishDecoding()
        return record!
    }
}
