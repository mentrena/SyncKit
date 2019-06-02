//
//  ServerToken.swift
//  Pods
//
//  Created by Manuel Entrena on 07/06/2018.
//

import Foundation
import Realm

class ServerToken: RLMObject {
    
    @objc dynamic var token: Data? = nil
}
