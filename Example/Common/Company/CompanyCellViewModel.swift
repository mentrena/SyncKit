//
//  CompanyCellViewModel.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 21/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation

struct CompanySection {
    let companies: [CompanyCellViewModel]
}

struct CompanyCellViewModel {
    let name: String
    let isSharing: Bool
    let isSharedWithMe: Bool
    let showShareStatus: Bool
    let shareAction: (()->())?
}
