//
//  APIForLDAPBridge.swift
//  EasyLoginServer
//
//  Created by Yoann Gini on 15/12/17.
//
//

import Foundation
import CouchDB
import Kitura

public class APIForLDAPBridge {
    let v1Bridge: APIForLDAPBridgeV1
    public init(database: Database) {
        v1Bridge = APIForLDAPBridgeV1(database:database)
    }
    
    public func router() -> Router {
        let router = Router()
        v1Bridge.installHandlers(to: router)
        return router
    }
    
    
    
}
