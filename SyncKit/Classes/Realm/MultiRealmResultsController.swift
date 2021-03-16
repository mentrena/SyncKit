//
//  MultiRealmResultsController.swift
//  Pods
//
//  Created by Manuel Entrena on 08/06/2018.
//

import Foundation
import Realm

public enum MultiRealmCollectionChange {
    /**
     `.update` indicates that a write transaction has been committed which
     either changed which objects are in the collection, and/or modified one
     or more of the objects in the collection.

     All three of the change arrays are always sorted in ascending order.

     - parameter deletions:     The indices in the previous version of the collection which were removed from this one.
     - parameter insertions:    The indices in the new collection which were added in this version.
     - parameter modifications: The indices of the objects in the new collection which were modified in this version.
     */
    case update(realmCount: Int, deletions: [IndexPath], insertions: [IndexPath], modifications: [IndexPath])

    /**
     If an error occurs, notification blocks are called one time with a `.error`
     result and an `NSError` containing details about the error. This can only
     currently happen if opening the Realm on a background thread to calcuate
     the change set fails. The callback will never be called again after it is
     invoked with a .error value.
     */
    case error(Error)
}

public class MultiRealmObserver {
    
    let id: UUID
    let block: (MultiRealmCollectionChange) -> Void
    private let _invalidate: (UUID) -> Void
    
    init(block: @escaping (MultiRealmCollectionChange) -> Void, invalidate: @escaping (UUID) -> Void) {
        self.block = block
        self.id = UUID()
        self._invalidate = invalidate
    }
    
    public func invalidate() {
        _invalidate(id)
    }
}

private class WeakReference<T: AnyObject> {
    weak var reference: T?
    init(reference: T) {
        self.reference = reference
    }
}

public class MultiRealmResultsController<T: RLMObject> {
    
    public private(set) var results: [RLMResults<T>]
    private var realmTokens: [RLMNotificationToken] = []
    private var listeners: [WeakReference<MultiRealmObserver>] = []
    
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
    
    public func observe(on queue: DispatchQueue? = nil, _ block: @escaping (MultiRealmCollectionChange) -> Void) -> MultiRealmObserver {
        let observer = MultiRealmObserver(block: block, invalidate: { [weak self] id in
            guard let self = self else { return }
            self.listeners = self.listeners.filter { $0.reference?.id == id }
        })
        self.listeners.append(WeakReference(reference: observer))
        return observer
    }
    
    func updateResults() {
        
        results = [RLMResults<T>]()
        
        provider.realms.forEach { (zoneID, configuration) in
            if let realm = try? RLMRealm(configuration: configuration) {
                let result = T.objects(in: realm, with: predicate) as! RLMResults<T>
                results.append(result)
            }
        }
        
        realmTokens = results.enumerated().map { index, realm in
            realm.addNotificationBlock { [weak self] (_, change, error) in
                guard let self = self else { return }
                
                self.listeners.removeAll { $0.reference == nil }
                
                if let error = error {
                    self.listeners.forEach { (observer) in
                        observer.reference?.block(.error(error))
                    }
                } else if let change = change {
                    self.listeners.forEach { (observer) in
                        observer.reference?.block(.update(realmCount: self.provider.realms.count,
                                                          deletions: change.deletions.map { IndexPath(item: Int(truncating: $0), section: index) },
                                                          insertions: change.insertions.map { IndexPath(item: Int(truncating: $0), section: index) },
                                                          modifications: change.modifications.map { IndexPath(item: Int(truncating: $0), section: index) }))
                    }
                }
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
