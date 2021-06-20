//
//  Identifier.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel on 20/06/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//

import Foundation
import RealmSwift

enum Identifier {
    case string(value: String)
    case int(value: Int)
    
    // This is not safe and would eventually collide, but it's good enough for my testing purposes where I just need to generate a handful of objects
    static func generateInt() -> Int {
        return Int.random(in: 0..<Int.max)
    }
}
