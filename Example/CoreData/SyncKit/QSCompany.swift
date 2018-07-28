//  Converted to Swift 4 by Swiftify v4.1.6781 - https://objectivec2swift.com/
//
//  QSCompany.swift
//  SyncKit
//
//  Created by Manuel Entrena on 30/12/2016.
//  Copyright © 2016 Manuel. All rights reserved.
//

import CoreData
import Foundation
import SyncKit

@objc(QSCompany)
public class QSCompany: NSManagedObject, QSPrimaryKey {
    public class func primaryKey() -> String {
        return "identifier"
    }
}
