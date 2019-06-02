//
//  QSRecord.swift
//  Pods-SyncKitRealmExample
//
//  Created by Manuel Entrena on 24/06/2019.
//

import Foundation
import Realm

class Record: RLMObject {
    @objc dynamic var encodedRecord: Data?
}
