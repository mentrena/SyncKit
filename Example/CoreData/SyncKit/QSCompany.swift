//
//  QSCompany.swift
//  SyncKit
//
//  Created by Jérôme Haegeli on 25.07.18.
//  Copyright © 2018 Manuel. All rights reserved.
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
