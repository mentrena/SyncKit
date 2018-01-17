//
//  QSCloudKitSynchronizer+MultiRealmResultsController.swift
//  Pods
//
//  Created by Manuel Entrena on 10/06/2018.
//

import Foundation
import RealmSwift

extension QSCloudKitSynchronizer {
    
    public func multiRealmResultsController<T: Object>(predicate: NSPredicate? = nil) -> MultiRealmResultsController<T>? {
        
        if let provider = self.adapterProvider as? DefaultRealmProvider {
            return MultiRealmResultsController(provider: provider, predicate: predicate)
        }
        return nil
    }
}
