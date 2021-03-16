//
//  KeyValueStore.swift
//  Pods-CoreDataExample
//
//  Created by Manuel Entrena on 25/04/2019.
//

import Foundation


/// Interface for persisting and loading values.
@objc public protocol KeyValueStore {
    
    
    /// Returns the object associated with the specified key.
    /// - Parameter defaultName: A key in the current store.
    func object(forKey defaultName: String) -> Any?
    
    /// Returns the Boolean value associated with the specified key.
    /// - Parameter defaultName: A key in the current store.
    func bool(forKey defaultName: String) -> Bool
    
    /// Sets the value of the specified key.
    /// - Parameters:
    ///   - value: The object to store in the store.
    ///   - defaultName: The key with which to associate the value.
    func set(value: Any?, forKey defaultName: String)
    
    /// Sets the value of the specified key to the specified Boolean value.
    /// - Parameters:
    ///   - boolValue: The Boolean value to store.
    ///   - defaultName: The key with which to associate the value.
    func set(boolValue: Bool, forKey defaultName: String)
    
    /// Removes the value of the specified default key.
    /// - Parameter defaultName: The key whose value you want to remove.
    func removeObject(forKey defaultName: String)
}


/// Implementation of `KeyValueStore` using `UserDefaults`
@objc public class UserDefaultsAdapter: NSObject, KeyValueStore {
    
    
    /// `UserDefaults` used internally by this adapter.
    @objc public let userDefaults: UserDefaults
    
    /// Creates a new `UserDefaultsAdapter` with the given default.
    /// - Parameter userDefaults: `UserDefaults` instance.
    @objc public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
    
    /// Returns the object associated with the specified key.
    /// - Parameter defaultName: A key in the current store.
    @objc public func object(forKey defaultName: String) -> Any? {
        return userDefaults.object(forKey: defaultName)
    }
    
    /// Returns the Boolean value associated with the specified key.
    /// - Parameter defaultName: A key in the current store.
    @objc public func bool(forKey defaultName: String) -> Bool {
        return userDefaults.bool(forKey: defaultName)
    }
    
    /// Sets the value of the specified key.
    /// - Parameters:
    ///   - value: The object to store in the store.
    ///   - defaultName: The key with which to associate the value.
    @objc public func set(value: Any?, forKey defaultName: String) {
        userDefaults.set(value, forKey: defaultName)
    }
    
    /// Sets the value of the specified key to the specified Boolean value.
    /// - Parameters:
    ///   - boolValue: The Boolean value to store.
    ///   - defaultName: The key with which to associate the value.
    @objc public func set(boolValue: Bool, forKey defaultName: String) {
        userDefaults.set(boolValue, forKey: defaultName)
    }
    
    /// Removes the value of the specified default key.
    /// - Parameter defaultName: The key whose value you want to remove.
    @objc public func removeObject(forKey defaultName: String) {
        userDefaults.removeObject(forKey: defaultName)
    }
}
