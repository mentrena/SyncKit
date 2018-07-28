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
