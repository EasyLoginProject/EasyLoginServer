//
//  EasyLoginServiceEnabler.swift
//  Application
//
//  Created by Frank on 07/05/2018.
//

import Foundation
import Kitura
import KituraNet
import CouchDB
import DataProvider
import EasyLoginDirectoryService
import EasyLoginLDAPGatewayAPI
import EasyLoginAdminAPI

class EasyLoginServiceEnabler: RouterMiddleware {
    enum Error: Swift.Error {
        case running
    }
    
    var enabled: Bool = false
    var error: Swift.Error?
    
    func start(withDatabase database: Database) {
        guard enabled == false else {
            fatalError("Service is already running.")
        }
        
        let dataProvider = DataProvider(database: database)
        let directoryService = EasyLoginDirectoryService(database: database, dataProvider: dataProvider)
        router.all(middleware: EasyLoginAuthenticator(userProvider: database))
        router.all("/db", middleware: directoryService.router())
        
        let ldapGatewayAPI = LDAPGatewayAPI(dataProvider: dataProvider)
        router.all("/ldap", middleware: ldapGatewayAPI.router())
        
        let adminAPI = AdminAPI(dataProvider: dataProvider)
        router.all("/admapi", middleware: adminAPI.router())
        
        enabled = true
    }
    
    func stop(withError error: Swift.Error?) {
        self.enabled = false;
        self.error = error
    }
    
    func handle(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        if enabled {
            next()
        }
        else {
            try response.send(status:.serviceUnavailable).end()
        }
    }
}
