//
//  QSCloudKitSynchronizer+MultiRealmResultsController.swift
//  Pods
//
//  Created by Manuel Entrena on 10/06/2018.
//

import Foundation
import Realm

extension CloudKitSynchronizer {
    
    public func multiRealmResultsController<T: RLMObject>(predicate: NSPredicate? = nil) -> MultiRealmResultsController<T>? {
        
        if let provider = self.adapterProvider as? DefaultRealmProvider {
            return MultiRealmResultsController(provider: provider, predicate: predicate)
        }
        return nil
    }
    
    public var realms: [RLMRealm] {
        let provider = adapterProvider as? DefaultRealmProvider
        return provider?.realms.values.compactMap { try? RLMRealm(configuration: $0) } ?? []
    }
}
