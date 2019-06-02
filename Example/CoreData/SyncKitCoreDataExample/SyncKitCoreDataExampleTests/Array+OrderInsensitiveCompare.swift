//
//  Array+OrderInsensitiveCompare.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 09/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation

extension Array where Element: Equatable {
    func orderInsensitiveEqual(_ array: Array?) -> Bool {
        guard let array = array else { return false }
        for item in self {
            if !array.contains(item) {
                return false
            }
        }
        return count == array.count
    }
}
