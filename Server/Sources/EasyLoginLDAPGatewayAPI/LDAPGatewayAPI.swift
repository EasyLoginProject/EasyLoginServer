//
//  LDAPGatewayAPI.swift
//  EasyLoginServer
//
//  Created by Yoann Gini on 15/12/17.
//
//

import Foundation
import Kitura
import DataProvider
import LoggerAPI

public class LDAPGatewayAPI {
    let v1Gateway: LDAPGatewayAPIv1
    public init(dataProvider: DataProvider) {
        v1Gateway = LDAPGatewayAPIv1(dataProvider: dataProvider)
    }
    
    public func router() -> Router {
        let router = Router()
        v1Gateway.installHandlers(to: router)
        return router
    }    
}
