//
//  MultiRealmResultsController.swift
//  Pods
//
//  Created by Manuel Entrena on 08/06/2018.
//

import Foundation
import Realm

public class MultiRealmResultsController<T: RLMObject> {
    
    public private(set) var results: [RLMResults<T>]
    
    public var didChangeRealms: ((MultiRealmResultsController<T>)->())?
    
    public let provider: DefaultRealmProvider
    public let predicate: NSPredicate?
    
    init(provider: DefaultRealmProvider, predicate: NSPredicate?) {
        self.provider = provider
        self.predicate = predicate
        results = [RLMResults<T>]()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeAdapters(notification:)), name: .realmProviderDidAddAdapter, object: provider)
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeAdapters(notification:)), name: .realmProviderDidRemoveAdapter, object: provider)
        
        updateResults()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateResults() {
        
        results = [RLMResults<T>]()
        
        provider.realms.forEach { (zoneID, configuration) in
            if let realm = try? RLMRealm(configuration: configuration) {
                let result = T.objects(in: realm, with: predicate) as! RLMResults<T>
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
