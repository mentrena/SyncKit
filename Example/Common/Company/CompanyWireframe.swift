//
//  CompanyWireframe.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation

protocol CompanyWireframe: class {
    func show(company: Company, canEdit: Bool)
}
