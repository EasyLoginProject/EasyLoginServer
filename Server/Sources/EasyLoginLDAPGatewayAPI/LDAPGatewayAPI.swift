//
//  LDAPGatewayAPI.swift
//  EasyLoginServer
//
//  Created by Yoann Gini on 15/12/17.
//
//

import Foundation
import CouchDB
import Kitura

public class LDAPGatewayAPI {
    let v1Gateway: LDAPGatewayAPIv1
    public init() throws {
        v1Gateway = try LDAPGatewayAPIv1()
    }
    
    public func router() -> Router {
        let router = Router()
        v1Gateway.installHandlers(to: router)
        return router
    }
    
    
    
}
