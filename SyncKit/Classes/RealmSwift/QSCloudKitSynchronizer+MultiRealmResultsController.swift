//
//  QSCloudKitSynchronizer+MultiRealmResultsController.swift
//  Pods
//
//  Created by Manuel Entrena on 10/06/2018.
//

import Foundation
import RealmSwift

extension CloudKitSynchronizer {
    
    public func multiRealmResultsController<T: Object>(predicate: NSPredicate? = nil) -> MultiRealmResultsController<T>? {
        
        if let provider = self.adapterProvider as? DefaultRealmProvider {
            return MultiRealmResultsController(provider: provider, predicate: predicate)
        }
        return nil
    }
    
    public var realms: [Realm] {
        let provider = adapterProvider as? DefaultRealmProvider
        return provider?.realms.values.compactMap { try? Realm(configuration: $0) } ?? []
    }
}
