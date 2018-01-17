//
//  MultiRealmResultsController.swift
//  Pods
//
//  Created by Manuel Entrena on 08/06/2018.
//

import Foundation
import RealmSwift

public class MultiRealmResultsController<T: Object> {
    
    public private(set) var results: [Results<T>]
    
    public var didChangeRealms: ((MultiRealmResultsController<T>)->())?
    
    let provider: DefaultRealmProvider
    let predicate: NSPredicate?
    
    init(provider: DefaultRealmProvider, predicate: NSPredicate?) {
        self.provider = provider
        self.predicate = predicate
        results = [Results<T>]()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeAdapters(notification:)), name: .realmProviderDidAddAdapter, object: provider)
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeAdapters(notification:)), name: .realmProviderDidRemoveAdapter, object: provider)
        
        updateResults()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateResults() {
        
        results = [Results<T>]()
        
        provider.realms.forEach { (zoneID, configuration) in
            if let realm = try? Realm(configuration: configuration) {
                var result = realm.objects(T.self)
                if let predicate = predicate {
                    result = result.filter(predicate)
                }
                results.append(result)
            }
        }
    }
    
    @objc func didChangeAdapters(notification: Notification) {
        
        DispatchQueue.main.async {
            self.updateResults()
            self.didChangeRealms?(self)
        }
    }
}
