//
//  Identifier.swift
//
//  Created by Manuel on 20/06/2021.
//  Copyright © 2021 Manuel Entrena. All rights reserved.
//

import Foundation

enum Identifier: Equatable {
    case string(value: String)
    case int(value: Int)
    
    // This is not safe and would eventually collide, but it's good enough for my testing purposes where I just need to generate a handful of objects
    static func generateInt() -> Int {
        return Int.random(in: 0..<Int.max)
    }
    
    var stringValue: String? {
        guard case Identifier.string(let value) = self else { return nil }
        return value
    }
    
    var intValue: Int? {
        guard case Identifier.int(let value) = self else { return nil }
        return value
    }
}
