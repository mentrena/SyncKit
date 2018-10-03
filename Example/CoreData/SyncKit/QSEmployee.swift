//
//  QSEmployee.swift
//  SyncKit
//
//  Created by Jérôme Haegeli on 25.07.18.
//  Copyright © 2018 Manuel. All rights reserved.
//

import CoreData
import Foundation
import SyncKit

@objc(QSEmployee)
public class QSEmployee: NSManagedObject, QSPrimaryKey, QSParentKey {
    public class func primaryKey() -> String {
        return "identifier"
    }

    public class func parentKey() -> String {
        return "company"
    }
}
