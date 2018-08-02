//
//  QSCloudKitSynchronizer+Subscriptions.swift
//  Pods
//
//  Created by Manuel Entrena on 21/05/2018.
//

import Foundation

@objc public extension QSCloudKitSynchronizer {
    
    #if os(iOS) || os(OSX)
    
    /**
     *  Returns identifier for a registered `CKSubscription` to track changes.
     */
    
    @objc public func subscriptionID(forRecordZoneID zoneID: CKRecordZoneID) -> String? {
        return storedSubscriptionID(for:zoneID)
    }
    
    /**
     *  Creates a new subscription with CloudKit so the application can receive notifications when new changes happen. The application is responsible for registering for remote notifications and initiating synchronization when a notification is received. @see `CKSubscription`
     *
     *  -Paremeter zoneID   `CKRecordZoneID` to track for changes
     *  -Parameter completion Block that will be called after subscription is created, with an optional error.
     */
    
    @objc public func subscribeForChanges(in zoneID: CKRecordZoneID, completion: ((Error?)->())?) {
        
        guard subscriptionID(forRecordZoneID: zoneID) == nil else {
            completion?(nil)
            return
        }
        
        database.fetchAllSubscriptions { (subscriptions, error) in
            guard error == nil else {
                completion?(error)
                return
            }
            
            let existingSubscription = subscriptions?.first {
                let subscription = $0 as? CKRecordZoneSubscription
                return subscription?.zoneID == zoneID
            }
            if let subscription = existingSubscription {
                // Found existing subscription
                self.storeSubscriptionID(subscription.subscriptionID, for: zoneID)
                completion?(nil)
            } else {
                // Create new one
                let subscription = CKRecordZoneSubscription(zoneID: zoneID)
                let notificationInfo = CKNotificationInfo()
                notificationInfo.shouldSendContentAvailable = true
                subscription.notificationInfo = notificationInfo
                
                self.database.save(subscription, completionHandler: { (subscription, error) in
                    if error == nil,
                        let subscription = subscription {
                        
                        self.storeSubscriptionID(subscription.subscriptionID, for: zoneID)
                    }
                    
                    completion?(error)
                })
            }
        }
    }
    
    /**
     *  Delete existing subscription to stop receiving notifications.
     *
     *  -Parameter zoneID `CKRecordZoneID` to stop tracking for changes.
     *  -Parameter completion Block that will be called after subscription is deleted, with an optional error.
     */
    
    @objc public func cancelSubscriptionForChanges(in zoneID: CKRecordZoneID, completion: ((Error?)->())?) {
        
        if let subscriptionID = subscriptionID(forRecordZoneID: zoneID) {
            
            self.cancelSubscription(identifier: subscriptionID, completion: completion)
        } else {
            // There might be an existing subscription in the server
            database.fetchAllSubscriptions { (subscriptions, error) in
                guard error == nil else {
                    completion?(error)
                    return
                }
                
                let existingSubscriptionIdentifier = subscriptions?.first {
                    let subscription = $0 as? CKRecordZoneSubscription
                    return subscription?.zoneID == zoneID
                }
                
                if let subscriptionID = existingSubscriptionIdentifier?.subscriptionID {
                    
                    self.cancelSubscription(identifier: subscriptionID, completion: completion)
                } else {
                    // No subscription to cancel
                    completion?(nil)
                }
            }
        }
    }
    
    fileprivate func cancelSubscription(identifier: String, completion: ((Error?)->())?) {
        
        database.delete(withSubscriptionID: identifier) { (subscriptionID, error) in
            self.clearSubscriptionID(subscriptionID)
            completion?(error)
        }
    }
    
    #endif
}

