//
//  SettingsManager.swift
//  SyncKitCoreDataExample
//
//  Created by Manuel Entrena on 20/12/2019.
//  Copyright © 2019 Manuel Entrena. All rights reserved.
//

import Foundation

protocol SettingsManagerDelegate: class {
    func didSetSyncEnabled(value: Bool)
}

public extension Notification.Name {
    static let SettingsManagerDidChangeSyncEnabled = Notification.Name("SettingsManagerDidChangeSyncEnabled")
}

class SettingsManager {
    
    private let syncEnabledKey = "SyncKitExample.syncEnabledKey"
    weak var delegate: SettingsManagerDelegate?
    
    init() {
        if UserDefaults.standard.object(forKey: syncEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: syncEnabledKey)
        }
    }
    
    var isSyncEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: syncEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: syncEnabledKey)
            delegate?.didSetSyncEnabled(value: newValue)
            NotificationCenter.default.post(name: .SettingsManagerDidChangeSyncEnabled, object: self)
        }
    }
}
