//
//  MockKeyValueStore.swift
//  SyncKitCoreDataExampleTests
//
//  Created by Manuel Entrena on 12/06/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation
import SyncKit

class MockKeyValueStore: KeyValueStore {
    
    private var dictionary = [String: Any]()
    
    func object(forKey defaultName: String) -> Any? {
        return dictionary[defaultName]
    }
    
    func bool(forKey defaultName: String) -> Bool {
        return dictionary[defaultName] as? Bool ?? false
    }
    
    func set(value: Any?, forKey defaultName: String) {
        dictionary[defaultName] = value
    }
    
    func set(boolValue: Bool, forKey defaultName: String) {
        dictionary[defaultName] = boolValue
    }
    
    func removeObject(forKey defaultName: String) {
        dictionary.removeValue(forKey: defaultName)
    }
    
    func clear() {
        dictionary.removeAll()
    }
}
