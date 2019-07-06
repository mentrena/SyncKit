//
//  KeyValueStore.swift
//  Pods-CoreDataExample
//
//  Created by Manuel Entrena on 25/04/2019.
//

import Foundation

@objc public protocol KeyValueStore {
    
    func object(forKey defaultName: String) -> Any?
    func bool(forKey defaultName: String) -> Bool
    func set(value: Any?, forKey defaultName: String)
    func set(boolValue: Bool, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

@objc public class UserDefaultsAdapter: NSObject, KeyValueStore {
    
    @objc public let userDefaults: UserDefaults
    @objc public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
    
    @objc public func object(forKey defaultName: String) -> Any? {
        return userDefaults.object(forKey: defaultName)
    }
    
    @objc public func bool(forKey defaultName: String) -> Bool {
        return userDefaults.bool(forKey: defaultName)
    }
    
    @objc public func set(value: Any?, forKey defaultName: String) {
        userDefaults.set(value, forKey: defaultName)
    }
    
    @objc public func set(boolValue: Bool, forKey defaultName: String) {
        userDefaults.set(boolValue, forKey: defaultName)
    }
    
    @objc public func removeObject(forKey defaultName: String) {
        userDefaults.removeObject(forKey: defaultName)
    }
}
