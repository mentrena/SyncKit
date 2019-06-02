//
//  ServerToken.swift
//  Pods
//
//  Created by Manuel Entrena on 07/06/2018.
//

import Foundation
import RealmSwift

class ServerToken: Object {
    
    @objc dynamic var token: Data? = nil
}
